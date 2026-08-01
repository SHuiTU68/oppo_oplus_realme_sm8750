#!/usr/bin/env python3
"""
ReSukiSU Manual Hook + SUSFS Coexistence Patcher
For kernel 6.6 (GKI 2.0, ARM64)

Modifies ReSukiSU kernel source so that CONFIG_KSU_MANUAL_HOOK and
CONFIG_KSU_SUSFS can both be enabled simultaneously:

1. Kconfig: convert the "KernelSU Hooking Method" choice block (which
   makes KSU_TRACEPOINT_HOOK / KSU_MANUAL_HOOK / KSU_SUSFS mutually
   exclusive) into three independent bool configs, so MANUAL_HOOK and
   SUSFS can coexist.

2. init.c: the ksu_hook_init() #elif chain only calls susfs_init() in
   the SUSFS branch. When MANUAL_HOOK is also defined the #elif takes
   the manual branch and susfs_init() is never reached. This patch adds
   a guarded susfs_init() call inside the manual hook branch.

3. Kbuild: the if/elif/elif chain on the hook method only includes
   tools/susfs_compat.mk in the CONFIG_KSU_SUSFS branch. That mk file
   defines -DKSU_COMPAT_HAS_SUSFS_FEATURE_SELINUX_HIDE, which makes
   selinux_hide.c export its symbols (ksu_selinux_hide_running,
   fake_status, security_*_with_policy, ...) globally instead of
   'static'. In coexistence mode the elif chain takes the manual branch,
   so susfs_compat.mk is never included and those symbols stay 'static',
   but the 50_add_susfs kernel patch already references them in
   security/selinux/selinuxfs.c -> link error. This patch includes
   susfs_compat.mk in the manual branch too, gated on CONFIG_KSU_SUSFS.

4. runtime/ksud_integration.c: the hook-type #elif chain
   (#if TRACEPOINT / #elif SUSFS / #elif MANUAL / #else) is ordered with
   SUSFS before MANUAL. In coexistence the preprocessor matches SUSFS
   first. The SUSFS branch defines ksu_is_init_rc_hook_enabled /
   ksu_is_input_hook_enabled (referenced by the 50_add_susfs kernel patch
   in drivers/input/input.c, fs/stat.c, fs/read_write.c under
   #ifdef CONFIG_KSU_SUSFS), so the order CANNOT be changed. But the
   MANUAL branch (now skipped) defines ksu_init_rc_hook / ksu_input_hook,
   which hook/lsm_hooks.c references via extern when AUTO_INITRC_HOOK /
   AUTO_INPUT_HOOK is on -> link error. This patch injects the
   ksu_init_rc_hook / ksu_input_hook symbol definitions into the SUSFS
   branch (guarded by #ifdef CONFIG_KSU_MANUAL_HOOK), so coexistence
   provides BOTH sets of symbols. The *_inactive() macros and
   stop_*_hook() functions remain SUSFS-owned (operating on
   ksu_is_*_hook_enabled), which is correct.

Feasibility: SUSFS has been implemented in APatch via a kpm module,
proving SUSFS can run independently of the KSU hook mechanism. The
50_add_susfs kernel patch inserts all root hook calls
(ksu_handle_stat / execveat / faccessat / sys_reboot) under
#ifdef CONFIG_KSU_SUSFS, and ReSukiSU sucompat.c provides those
function definitions unconditionally (guarded only by
!CONFIG_KSU_TRACEPOINT_HOOK). Therefore MANUAL_HOOK (providing
AUTO_*_HOOK for setuid/initrc/input via LSM) and SUSFS (providing
root hooks + hiding) can coexist.

Usage:
    python3 apply_resukisu_susfs_coexist.py <resukisu_kernel_dir>

    <resukisu_kernel_dir> should be the root of the cloned ReSukiSU
    kernel source tree (the directory containing kernel/Kconfig and
    kernel/core/init.c), e.g. "KernelSU".
"""

import os
import re
import sys


def read_file(filepath):
    with open(filepath, "r") as f:
        return f.read()


def write_file(filepath, content):
    with open(filepath, "w") as f:
        f.write(content)


# Replacement for the choice block: three independent bool configs.
# - KSU_TRACEPOINT_HOOK: add "depends on KSU" (was only on the choice)
# - KSU_MANUAL_HOOK: keep "depends on KSU != m"
# - KSU_SUSFS: add "depends on KSU" alongside existing THREAD_INFO_IN_TASK && 64BIT
INDEPENDENT_CONFIGS = (
    'config KSU_TRACEPOINT_HOOK\n'
    '\tbool "Tracepoint Syscall Redirect"\n'
    '\tdepends on KSU\n'
    '\thelp\n'
    '\t  The standard, upstream method for modern kernels.\n'
    '\t  Utilizes GKI tracepoints for syscall redirection.\n'
    '\t  The implementation is only for devices with GKI2 support.\n'
    '\t  Support for kernel 5.10+\n\n'
    'config KSU_MANUAL_HOOK\n'
    '\tbool "Manually hook KernelSU"\n'
    '\tdepends on KSU != m\n'
    '\thelp\n'
    '\t  If enabled, it hooks the required KernelSU syscalls\n'
    '\t  with a manually-patched function.\n'
    '\t  Support for kernel 3.4+\n\n'
    'config KSU_SUSFS\n'
    '\tbool "SUSFS Inline Hook"\n'
    '\tdepends on KSU && THREAD_INFO_IN_TASK && 64BIT\n'
    '\thelp\n'
    '\t  Patch and Enable SUSFS to kernel with KernelSU.\n'
    '\t  SuSFS Officially support kernel 5.10+\n'
    '\t  This KSU driver support it for 4.3+ in KSU side,\n'
    '\t  But the kernel side susfs compatibility MUST completed by yourself.'
)


def patch_kconfig(src_dir):
    """Convert the hooking-method choice block into independent bool configs."""
    filepath = os.path.join(src_dir, "kernel", "Kconfig")
    print(f"[*] Patching {filepath}...")
    content = read_file(filepath)

    # Already patched (idempotent): choice block gone, independent configs present
    if 'config KSU_TRACEPOINT_HOOK\n\tbool "Tracepoint Syscall Redirect"\n\tdepends on KSU\n' in content \
            and 'choice\n\tprompt "KernelSU Hooking Method"' not in content:
        print("    [SKIP] choice block already removed (already patched)")
        return True

    pattern = re.compile(
        r'choice\n\tprompt "KernelSU Hooking Method".*?endchoice',
        re.DOTALL,
    )
    new_content, n = pattern.subn(INDEPENDENT_CONFIGS, content)
    if n != 1:
        print(f"    [FAIL] choice block match count={n}, expected 1")
        print("           Please check ReSukiSU kernel/Kconfig source")
        return False

    write_file(filepath, new_content)
    print(f"    [OK] choice block -> 3 independent bool configs (replaced {n})")
    return True


def patch_init_c(src_dir):
    """Add susfs_init() call inside the manual hook branch of ksu_hook_init()."""
    filepath = os.path.join(src_dir, "kernel", "core", "init.c")
    print(f"[*] Patching {filepath}...")
    content = read_file(filepath)

    # Idempotent: already has susfs_init() in manual hook branch
    if 'susfs_init();\n#endif\n#elif defined(CONFIG_KSU_SUSFS)' in content:
        print("    [SKIP] susfs_init() already present in manual hook branch")
        return True

    old = (
        '#elif defined(CONFIG_KSU_MANUAL_HOOK)\n'
        '// only lsm hook need call init\n'
        '#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 8, 0)\n'
        '    ksu_lsm_hook_built_in_init();\n'
        '#endif\n'
        '#elif defined(CONFIG_KSU_SUSFS)'
    )
    new = (
        '#elif defined(CONFIG_KSU_MANUAL_HOOK)\n'
        '// only lsm hook need call init\n'
        '#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 8, 0)\n'
        '    ksu_lsm_hook_built_in_init();\n'
        '#endif\n'
        '#ifdef CONFIG_KSU_SUSFS\n'
        '    susfs_init();\n'
        '#endif\n'
        '#elif defined(CONFIG_KSU_SUSFS)'
    )

    if old not in content:
        print("    [FAIL] manual hook branch not found")
        print("           Please check ReSukiSU kernel/core/init.c source")
        return False

    content = content.replace(old, new, 1)
    write_file(filepath, content)
    print("    [OK] added susfs_init() call in manual hook branch")
    return True


def patch_ksud_integration_c(src_dir):
    """Add ksu_init_rc_hook / ksu_input_hook definitions in the SUSFS branch.

    runtime/ksud_integration.c has an #elif chain on the hook type:
        #if defined(CONFIG_KSU_TRACEPOINT_HOOK)
        #elif defined(CONFIG_KSU_SUSFS)            // defines ksu_is_*_hook_enabled
        #elif defined(CONFIG_KSU_MANUAL_HOOK)      // defines ksu_init_rc_hook / ksu_input_hook
        #endif
    The order matters: the 50_add_susfs kernel patch references
    `extern struct static_key_true ksu_is_input_hook_enabled;` (in
    drivers/input/input.c) and `ksu_is_init_rc_hook_enabled` (in
    fs/stat.c, fs/read_write.c) under `#ifdef CONFIG_KSU_SUSFS`. So in
    coexistence mode the SUSFS branch MUST be matched to provide those
    symbols -> we CANNOT reorder MANUAL before SUSFS.

    But hook/lsm_hooks.c (compiled when AUTO_INITRC_HOOK / AUTO_INPUT_HOOK
    is on) references `extern struct static_key_true ksu_init_rc_hook;` and
    `ksu_input_hook;`, which are only defined in the MANUAL branch. In
    coexistence the MANUAL branch is skipped (SUSFS matched first) ->
    link error: undefined symbol: ksu_init_rc_hook / ksu_input_hook.

    Fix: keep the original #elif order (SUSFS before MANUAL), but inject
    the MANUAL branch's ksu_init_rc_hook / ksu_input_hook definitions
    (and their inactive macros / stop functions) into the SUSFS branch,
    guarded by `#ifdef CONFIG_KSU_MANUAL_HOOK` + the AUTO_*_HOOK configs.
    This way coexistence provides BOTH sets of symbols:
      - ksu_is_*_hook_enabled  (for 50_add_susfs kernel patch, from SUSFS branch)
      - ksu_init_rc_hook / ksu_input_hook (for lsm_hooks.c, from injected block)
    Pure SUSFS / pure MANUAL modes are untouched (the injected block is
    guarded by CONFIG_KSU_MANUAL_HOOK so it's skipped in pure-SUSFS builds).
    """
    filepath = os.path.join(src_dir, "kernel", "runtime", "ksud_integration.c")
    print(f"[*] Patching {filepath}...")
    content = read_file(filepath)

    # Idempotent: already injected (check for the injection marker comment)
    if "coexist: provide ksu_init_rc_hook / ksu_input_hook symbols for" in content:
        print("    [SKIP] ksu_init_rc_hook/ksu_input_hook already injected in SUSFS branch")
        return True

    # Anchor: the SUSFS branch defines ksu_is_init_rc_hook_enabled right after
    # "#elif defined(CONFIG_KSU_SUSFS)\n". We inject the MANUAL_HOOK block
    # immediately after those two DEFINE_STATIC_KEY_TRUE lines.
    anchor = (
        "#elif defined(CONFIG_KSU_SUSFS)\n"
        "    DEFINE_STATIC_KEY_TRUE(ksu_is_init_rc_hook_enabled);\n"
        "    DEFINE_STATIC_KEY_TRUE(ksu_is_input_hook_enabled);\n"
    )
    if anchor not in content:
        print("    [FAIL] SUSFS branch anchor (ksu_is_*_hook_enabled defines) not found")
        print("           Please check ReSukiSU kernel/runtime/ksud_integration.c source")
        return False

    # Injection block: define ONLY the symbols (ksu_init_rc_hook /
    # ksu_input_hook) that lsm_hooks.c references via extern. Do NOT define
    # the *_inactive() macros here - the SUSFS branch already defines them
    # (operating on ksu_is_*_hook_enabled) right after this block, and those
    # are the correct ones for stop_init_rc_hook/stop_input_hook to use.
    # The injected symbols are guarded by CONFIG_KSU_MANUAL_HOOK so pure-SUSFS
    # builds skip them entirely.
    inject = anchor + (
        "\n"
        "    /* coexist: provide ksu_init_rc_hook / ksu_input_hook symbols for\n"
        "     * hook/lsm_hooks.c (which references them via extern when\n"
        "     * AUTO_INITRC_HOOK / AUTO_INPUT_HOOK is on). In coexistence the\n"
        "     * MANUAL #elif branch is skipped (SUSFS matches first), so define\n"
        "     * them here. The *_inactive() macros below still use\n"
        "     * ksu_is_*_hook_enabled (the SUSFS-owned keys), which is correct\n"
        "     * because stop_init_rc_hook/stop_input_hook operate on those. */\n"
        "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
        "    #if defined(CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK) && defined(KSU_COMPAT_USE_STATIC_KEY)\n"
        "        DEFINE_STATIC_KEY_TRUE(ksu_init_rc_hook);\n"
        "    #elif !defined(CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK)\n"
        "        bool ksu_init_rc_hook __read_mostly = true;\n"
        "    #endif\n"
        "    #if defined(CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK) && defined(KSU_COMPAT_USE_STATIC_KEY)\n"
        "        DEFINE_STATIC_KEY_TRUE(ksu_input_hook);\n"
        "    #elif !defined(CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK)\n"
        "        bool ksu_input_hook __read_mostly = true;\n"
        "    #endif\n"
        "#endif\n"
    )

    content = content.replace(anchor, inject, 1)
    write_file(filepath, content)
    print("    [OK] injected ksu_init_rc_hook/ksu_input_hook defines into SUSFS branch")
    return True


def patch_kbuild(src_dir):
    """Include susfs_compat.mk in the manual hook branch when SUSFS is also enabled.

    ReSukiSU Kbuild uses an if/elif/elif chain on the hook method. The
    susfs_compat.mk (which defines -DKSU_COMPAT_HAS_SUSFS_FEATURE_SELINUX_HIDE
    so that selinux_hide.c exports its symbols globally instead of 'static')
    is only included in the CONFIG_KSU_SUSFS branch.

    When MANUAL_HOOK and SUSFS coexist, the elif chain takes the manual branch
    and susfs_compat.mk is never included. selinux_hide.c symbols stay 'static',
    but the 50_add_susfs kernel patch already references them in
    security/selinux/selinuxfs.c -> link error: undefined symbol.

    Fix: in the manual hook branch, also include susfs_compat.mk when
    CONFIG_KSU_SUSFS is defined. susfs_compat.mk has its own grep guard
    (only defines the macro if security/selinux/hooks.c contains
    ksu_selinux_hide_running), so this is safe for pure-manual builds
    too, but we gate it on CONFIG_KSU_SUSFS to preserve exact original
    behavior for the pure-manual (no SUSFS) case.
    """
    filepath = os.path.join(src_dir, "kernel", "Kbuild")
    print(f"[*] Patching {filepath}...")
    content = read_file(filepath)

    old = (
        "else ifdef CONFIG_KSU_MANUAL_HOOK\n"
        "  $(info -- $(REPO_NAME): using Manual Hook)\n"
        "  include $(KSU_SRC)/tools/manual_hook_check.mk\n"
        "else ifdef CONFIG_KSU_SUSFS\n"
    )
    new = (
        "else ifdef CONFIG_KSU_MANUAL_HOOK\n"
        "  $(info -- $(REPO_NAME): using Manual Hook)\n"
        "  include $(KSU_SRC)/tools/manual_hook_check.mk\n"
        "  ifdef CONFIG_KSU_SUSFS\n"
        "    include $(KSU_SRC)/tools/susfs_compat.mk\n"
        "  endif\n"
        "else ifdef CONFIG_KSU_SUSFS\n"
    )

    # Idempotent: already patched
    if "  ifdef CONFIG_KSU_SUSFS\n    include $(KSU_SRC)/tools/susfs_compat.mk\n  endif\nelse ifdef CONFIG_KSU_SUSFS" in content:
        print("    [SKIP] Kbuild manual branch already includes susfs_compat.mk")
        return True

    if old not in content:
        print("    [FAIL] manual hook branch in Kbuild not found")
        print("           Please check ReSukiSU kernel/Kbuild source")
        return False

    content = content.replace(old, new, 1)
    write_file(filepath, content)
    print("    [OK] manual hook branch now includes susfs_compat.mk when CONFIG_KSU_SUSFS")
    return True


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 apply_resukisu_susfs_coexist.py <resukisu_kernel_dir>")
        print("       <resukisu_kernel_dir> = root of cloned ReSukiSU kernel tree")
        print('       e.g. "KernelSU"')
        sys.exit(1)

    src_dir = sys.argv[1]
    if not os.path.isdir(src_dir):
        print(f"::error::directory not found: {src_dir}")
        sys.exit(1)

    print(f"=== ReSukiSU Manual Hook + SUSFS Coexistence Patcher ===")
    print(f"Source dir: {src_dir}")
    print()

    ok = True
    ok = patch_kconfig(src_dir) and ok
    print()
    ok = patch_init_c(src_dir) and ok
    print()
    ok = patch_ksud_integration_c(src_dir) and ok
    print()
    ok = patch_kbuild(src_dir) and ok

    print()
    if ok:
        print("=== All patches applied successfully ===")
        print("CONFIG_KSU_MANUAL_HOOK=y and CONFIG_KSU_SUSFS=y can now coexist.")
    else:
        print("::error::Some patches FAILED, see output above")
        sys.exit(1)


if __name__ == "__main__":
    main()
