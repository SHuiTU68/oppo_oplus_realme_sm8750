#!/usr/bin/env python3
"""
ReSukiSU Manual Hook Integration Script
For kernel 6.6 (GKI 2.0, ARM64)

Applies manual hook calls to kernel source files so that ReSukiSU
can use CONFIG_KSU_MANUAL_HOOK=y instead of SUSFS inline hook or
tracepoint syscall redirect.

Reference: https://resukisu.github.io/guide/manual-integrate.html

Usage:
    python3 apply_manual_hook.py <kernel_source_dir>

    <kernel_source_dir> should be the root of the kernel source tree
    (the directory containing fs/, kernel/, etc.)
"""

import os
import re
import sys


def read_file(filepath):
    with open(filepath, 'r') as f:
        return f.read()


def write_file(filepath, content):
    with open(filepath, 'w') as f:
        f.write(content)


def patch_stat_c(src_dir):
    """Patch fs/stat.c with stat hooks."""
    filepath = os.path.join(src_dir, 'fs/stat.c')
    print(f"[*] Patching {filepath}...")
    content = read_file(filepath)

    stat_hook_present = 'ksu_handle_stat' in content
    if stat_hook_present:
        print("    [SKIP] ksu_handle_stat already present (likely from SUSFS patch)")

    # 1. Add extern declarations before the newfstatat function section
    if not stat_hook_present:
        decl_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_stat(int *dfd, const char __user **filename_user,
\t\t\tint *flags);

extern void ksu_handle_newfstat_ret(unsigned int *fd, struct stat __user **statbuf_ptr);
#if defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_COMPAT_STAT64)
extern void ksu_handle_fstat64_ret(unsigned long *fd, struct stat64 __user **statbuf_ptr);
#endif
#endif

"""
        # Try to insert before the newfstatat function definition or its guard
        pattern = re.compile(
            r'(\n*(?:#if !defined\(__ARCH_WANT_STAT64\) \|\| defined\(__ARCH_WANT_SYS_NEWFSTATAT\)\n)?'
            r'SYSCALL_DEFINE4\(newfstatat,)',
            re.MULTILINE
        )
        match = pattern.search(content)
        if match:
            content = content[:match.start()] + '\n' + decl_block + content[match.start():]
            print("    [OK] Added extern declarations before newfstatat")
        else:
            print("    [WARN] Could not find newfstatat insertion point for declarations")
            return False
    elif 'ksu_handle_newfstat_ret' not in content:
        # SUSFS patch already added ksu_handle_stat but not newfstat_ret
        # Add only newfstat_ret/fstat64_ret declarations before newfstat function
        decl_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
extern void ksu_handle_newfstat_ret(unsigned int *fd, struct stat __user **statbuf_ptr);
#if defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_COMPAT_STAT64)
extern void ksu_handle_fstat64_ret(unsigned long *fd, struct stat64 __user **statbuf_ptr);
#endif
#endif

"""
        pattern = re.compile(r'(\n*SYSCALL_DEFINE2\(newfstat,)', re.MULTILINE)
        match = pattern.search(content)
        if match:
            content = content[:match.start()] + '\n' + decl_block + content[match.start():]
            print("    [OK] Added newfstat_ret extern declaration (SUSFS patch detected)")
        else:
            print("    [WARN] Could not find newfstat insertion point for declaration")
            return False

    # 2-3. Add ksu_handle_stat calls (skip if already present from SUSFS patch)
    if not stat_hook_present:
        # 2. Add ksu_handle_stat call in newfstatat (after "int error;")
        hook_call_stat = """
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_stat(&dfd, &filename, &flag);
#endif
"""
        pattern = re.compile(
            r'(SYSCALL_DEFINE4\(newfstatat,.*?\{[^}]*?struct kstat stat;\s*\n\s*int error;\s*\n)',
            re.DOTALL
        )
        match = pattern.search(content)
        if match:
            insert_pos = match.end()
            content = content[:insert_pos] + hook_call_stat + content[insert_pos:]
            print("    [OK] Added ksu_handle_stat call in newfstatat")
        else:
            print("    [WARN] Could not find newfstatat hook insertion point")
            return False

        # 3. Add ksu_handle_stat call in fstatat64 (if exists, for 32-bit su)
        pattern = re.compile(
            r'(SYSCALL_DEFINE4\(fstatat64,.*?\{[^}]*?struct kstat stat;\s*\n\s*int error;\s*\n)',
            re.DOTALL
        )
        match = pattern.search(content)
        if match:
            insert_pos = match.end()
            hook_call_fstatat64 = """
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_stat(&dfd, &filename, &flag);
#endif
"""
            content = content[:insert_pos] + hook_call_fstatat64 + content[insert_pos:]
            print("    [OK] Added ksu_handle_stat call in fstatat64")
        else:
            print("    [INFO] fstatat64 not found (may not exist on this arch)")

    # 4. Add ksu_handle_newfstat_ret call in newfstat
    pattern = re.compile(
        r'(SYSCALL_DEFINE2\(newfstat,.*?cp_new_stat\(&stat, statbuf\);\s*\n)',
        re.DOTALL
    )
    match = pattern.search(content)
    if match:
        insert_pos = match.end()
        hook_call_newfstat = """
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_newfstat_ret(&fd, &statbuf);
#endif
"""
        content = content[:insert_pos] + hook_call_newfstat + content[insert_pos:]
        print("    [OK] Added ksu_handle_newfstat_ret call in newfstat")
    else:
        print("    [WARN] Could not find newfstat hook insertion point")
        return False

    # 5. Add ksu_handle_fstat64_ret call in fstat64 (if exists, for 32-bit)
    pattern = re.compile(
        r'(SYSCALL_DEFINE2\(fstat64,.*?cp_new_stat64\(&stat, statbuf\);\s*\n)',
        re.DOTALL
    )
    match = pattern.search(content)
    if match:
        insert_pos = match.end()
        hook_call_fstat64 = """
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_fstat64_ret(&fd, &statbuf);
#endif
"""
        content = content[:insert_pos] + hook_call_fstat64 + content[insert_pos:]
        print("    [OK] Added ksu_handle_fstat64_ret call in fstat64")
    else:
        print("    [INFO] fstat64 not found (may not exist on this arch)")

    write_file(filepath, content)
    return True


def patch_exec_c(src_dir):
    """Patch fs/exec.c with execveat hook."""
    filepath = os.path.join(src_dir, 'fs/exec.c')
    print(f"[*] Patching {filepath}...")
    content = read_file(filepath)

    if 'ksu_handle_execveat' in content:
        print("    [SKIP] ksu_handle_execveat already present")
        return True

    # 1. Add extern declaration before do_execve function
    # Note: do_execve may be declared as 'static int do_execve' (e.g. 6.6.118),
    # must match the optional 'static' prefix so the declaration is inserted
    # before 'static', otherwise 'static' would attach to the extern declaration
    # and cause "cannot combine with previous 'static' declaration specifier".
    decl_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr,
\t\t\tvoid *argv, void *envp, int *flags);
#endif

"""

    pattern = re.compile(r'((?:static\s+)?int do_execve\(struct filename)', re.MULTILINE)
    match = pattern.search(content)
    if match:
        content = content[:match.start()] + decl_block + content[match.start():]
        print("    [OK] Added extern declaration before do_execve")
    else:
        print("    [WARN] Could not find do_execve function")
        return False

    # 2. Add ksu_handle_execveat call in do_execve
    hook_call = """
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_execveat((int *)AT_FDCWD, &filename, &argv, &envp, 0);
#endif
"""
    pattern = re.compile(
        r'(int do_execve\(struct filename.*?struct user_arg_ptr envp = \{ \.ptr\.native = __envp \};\s*\n)',
        re.DOTALL
    )
    match = pattern.search(content)
    if match:
        insert_pos = match.end()
        content = content[:insert_pos] + hook_call + content[insert_pos:]
        print("    [OK] Added ksu_handle_execveat call in do_execve")
    else:
        print("    [WARN] Could not find do_execve hook insertion point")
        return False

    # 3. Add ksu_handle_execveat call in compat_do_execve (for 32-bit, if exists)
    pattern = re.compile(
        r'(static int compat_do_execve\(struct filename.*?\.ptr\.compat = __envp,\s*\n\s*\};\s*\n)',
        re.DOTALL
    )
    match = pattern.search(content)
    if match:
        insert_pos = match.end()
        hook_call_compat = """
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_execveat((int *)AT_FDCWD, &filename, &argv, &envp, 0);
#endif
"""
        content = content[:insert_pos] + hook_call_compat + content[insert_pos:]
        print("    [OK] Added ksu_handle_execveat call in compat_do_execve")
    else:
        print("    [INFO] compat_do_execve not found (may not exist on this arch)")

    write_file(filepath, content)
    return True


def patch_open_c(src_dir):
    """Patch fs/open.c with faccessat hook."""
    filepath = os.path.join(src_dir, 'fs/open.c')
    print(f"[*] Patching {filepath}...")
    content = read_file(filepath)

    if 'ksu_handle_faccessat' in content:
        print("    [SKIP] ksu_handle_faccessat already present")
        return True

    # 1. Add extern declaration before SYSCALL_DEFINE3(faccessat,
    decl_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user,
\t\t\tint *mode, int *flags);
#endif

"""

    pattern = re.compile(r'(SYSCALL_DEFINE3\(faccessat,)', re.MULTILINE)
    match = pattern.search(content)
    if match:
        content = content[:match.start()] + decl_block + content[match.start():]
        print("    [OK] Added extern declaration before faccessat")
    else:
        print("    [WARN] Could not find faccessat function")
        return False

    # 2. Add ksu_handle_faccessat call at start of faccessat function body
    hook_call = """
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);
#endif
"""
    pattern = re.compile(
        r'(SYSCALL_DEFINE3\(faccessat,.*?\{\s*\n)',
        re.DOTALL
    )
    match = pattern.search(content)
    if match:
        insert_pos = match.end()
        content = content[:insert_pos] + hook_call + content[insert_pos:]
        print("    [OK] Added ksu_handle_faccessat call in faccessat")
    else:
        print("    [WARN] Could not find faccessat hook insertion point")
        return False

    write_file(filepath, content)
    return True


def patch_reboot_c(src_dir):
    """Patch kernel/reboot.c with sys_reboot hook."""
    filepath = os.path.join(src_dir, 'kernel/reboot.c')
    print(f"[*] Patching {filepath}...")
    content = read_file(filepath)

    if 'ksu_handle_sys_reboot' in content:
        print("    [SKIP] ksu_handle_sys_reboot already present")
        return True

    # 1. Add extern declaration before SYSCALL_DEFINE4(reboot,
    decl_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);
#endif

"""

    pattern = re.compile(r'(SYSCALL_DEFINE4\(reboot,)', re.MULTILINE)
    match = pattern.search(content)
    if match:
        content = content[:match.start()] + decl_block + content[match.start():]
        print("    [OK] Added extern declaration before reboot")
    else:
        print("    [WARN] Could not find reboot syscall")
        return False

    # 2. Add ksu_handle_sys_reboot call at start of reboot function body
    hook_call = """
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_sys_reboot(magic1, magic2, cmd, &arg);
#endif
"""
    # Try to insert after "int ret = 0;" first
    pattern = re.compile(
        r'(SYSCALL_DEFINE4\(reboot,.*?\{[^}]*?int ret = 0;\s*\n)',
        re.DOTALL
    )
    match = pattern.search(content)
    if match:
        insert_pos = match.end()
        content = content[:insert_pos] + hook_call + content[insert_pos:]
        print("    [OK] Added ksu_handle_sys_reboot call in reboot")
    else:
        # Fallback: insert right after the opening brace
        pattern2 = re.compile(
            r'(SYSCALL_DEFINE4\(reboot,.*?\{\s*\n)',
            re.DOTALL
        )
        match2 = pattern2.search(content)
        if match2:
            insert_pos = match2.end()
            content = content[:insert_pos] + hook_call + content[insert_pos:]
            print("    [OK] Added ksu_handle_sys_reboot call in reboot (fallback)")
        else:
            print("    [WARN] Could not find reboot hook insertion point")
            return False

    write_file(filepath, content)
    return True


def verify_hooks(src_dir):
    """Verify all required hooks are present in the source files."""
    print("\n[*] Verifying manual hooks...")
    all_ok = True

    checks = [
        ('fs/exec.c', 'ksu_handle_execveat'),
        ('fs/open.c', 'ksu_handle_faccessat'),
        ('fs/stat.c', 'ksu_handle_stat'),
        ('fs/stat.c', 'ksu_handle_newfstat_ret'),
        ('kernel/reboot.c', 'ksu_handle_sys_reboot'),
    ]

    for relpath, hook_name in checks:
        filepath = os.path.join(src_dir, relpath)
        if not os.path.exists(filepath):
            print(f"    [FAIL] {relpath}: file not found")
            all_ok = False
            continue
        content = read_file(filepath)
        if hook_name in content:
            print(f"    [OK]   {relpath}: {hook_name} found")
        else:
            print(f"    [FAIL] {relpath}: {hook_name} NOT found")
            all_ok = False

    # Check for incompatible hooks (must NOT exist when using manual hook)
    incompatible_checks = [
        ('fs/read_write.c', 'ksu_vfs_read_hook'),
        ('security/selinux/hooks.c', 'is_ksu_transition'),
        ('security/security.c', 'ksu_handle_rename'),
    ]

    for relpath, hook_name in incompatible_checks:
        filepath = os.path.join(src_dir, relpath)
        if not os.path.exists(filepath):
            continue
        content = read_file(filepath)
        if hook_name in content:
            print(f"    [FAIL] {relpath}: incompatible hook {hook_name} found (must NOT exist)")
            all_ok = False
        else:
            print(f"    [OK]   {relpath}: no incompatible {hook_name}")

    return all_ok


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 apply_manual_hook.py <kernel_source_dir>")
        sys.exit(1)

    src_dir = os.path.abspath(sys.argv[1])
    if not os.path.isdir(src_dir):
        print(f"Error: {src_dir} is not a directory")
        sys.exit(1)

    print("=== ReSukiSU Manual Hook Integration ===")
    print(f"Kernel source: {src_dir}")
    print()

    results = []
    results.append(patch_stat_c(src_dir))
    results.append(patch_exec_c(src_dir))
    results.append(patch_open_c(src_dir))
    results.append(patch_reboot_c(src_dir))

    if not all(results):
        print("\n[ERROR] Some patches failed to apply!")
        sys.exit(1)

    if not verify_hooks(src_dir):
        print("\n[ERROR] Hook verification failed!")
        sys.exit(1)

    print("\n[SUCCESS] All manual hooks applied and verified!")


if __name__ == '__main__':
    main()
