#!/usr/bin/env python3
"""
ReSukiSU auto-hook Branch Symbol Definition Fixer
For kernel 6.6 (GKI 2.0, ARM64)

Fixes a link error in the ReSukiSU `auto-hook` branch when built with the
SUSFS hook method (CONFIG_KSU_SUSFS=y, the mode used by the resukisu-auto
workflow option):

    ld.lld: error: undefined symbol: ksu_handle_newfstat_ret
    ld.lld: error: undefined symbol: ksu_handle_fstat64_ret
        >>> referenced by auto_hook.c:448 (ksu_on_sys_newfstat)
        >>> referenced by auto_hook.c:503 (ksu_on_sys_fstat64)

Root cause:
  kernel/hook/auto_hook.c, under #ifdef KSU_HOOK_AUTO_NEWFSTAT_HOOK /
  KSU_HOOK_AUTO_FSTAT64_HOOK, extern-declares ksu_handle_newfstat_ret() /
  ksu_handle_fstat64_ret() and calls them from the inline-hook callbacks
  ksu_on_sys_newfstat / ksu_on_sys_fstat64.

  Those two functions are defined in kernel/runtime/ksud_integration.c,
  but the whole block is guarded by `#ifdef CONFIG_KSU_MANUAL_HOOK`
  (line ~594 .. ~679). In the resukisu-auto build we use the SUSFS hook
  method (CONFIG_KSU_SUSFS=y) WITHOUT CONFIG_KSU_MANUAL_HOOK, so:
    - auto_hook_detect.mk greps the kernel tree, finds no
      ksu_handle_newfstat_ret / ksu_handle_fstat64_ret calls in fs/stat.c
      (50_add_susfs patch only inserts ksu_handle_stat, not the *_ret
      variants), and therefore defines KSU_HOOK_AUTO_NEWFSTAT_HOOK /
      KSU_HOOK_AUTO_FSTAT64_HOOK -> auto_hook.c compiles the callbacks.
    - But CONFIG_KSU_MANUAL_HOOK is off, so ksud_integration.c skips the
      block that defines the two functions -> link error.

Fix:
  Widen the guard of the ksu_handle_newfstat_ret / ksu_handle_fstat64_ret
  definition block in ksud_integration.c from

      #ifdef CONFIG_KSU_MANUAL_HOOK
      ...
      #endif

  to

      #if defined(CONFIG_KSU_MANUAL_HOOK) || \\
          (defined(CONFIG_KSU_SUSFS) && \\
           (defined(KSU_HOOK_AUTO_NEWFSTAT_HOOK) || \\
            defined(KSU_HOOK_AUTO_FSTAT64_HOOK)))
      ...
      #endif

  so that the two symbols are also emitted in SUSFS mode when the
  auto-hook detector has turned on the newfstat / fstat64 inline hooks.

  All other symbols the block body depends on are available in SUSFS
  mode too:
    - ksu_init_rc_hook_inactive()  -> defined in the SUSFS #elif branch
      (operates on ksu_is_init_rc_hook_enabled)
    - is_init / is_init_rc / load_module_rc_once / ksu_rc_len /
      module_rc_len -> all defined outside any MANUAL_HOOK guard
  so no further changes are needed.

  Pure-MANUAL builds are unaffected (the widened #if still matches
  CONFIG_KSU_MANUAL_HOOK). Pure-SUSFS builds without the auto-hook
  detector (i.e. KSU_HOOK_AUTO_NEWFSTAT_HOOK / KSU_HOOK_AUTO_FSTAT64_HOOK
  both undefined) are also unaffected (the second operand of the || is
  false, so the block is skipped exactly as before).

Usage:
    python3 apply_resukisu_auto_fix.py <resukisu_kernel_dir>

    <resukisu_kernel_dir> should be the root of the cloned ReSukiSU
    kernel source tree checked out on the `auto-hook` branch (the
    directory containing kernel/runtime/ksud_integration.c), e.g.
    "KernelSU".
"""

import os
import sys


def read_file(filepath):
    with open(filepath, "r") as f:
        return f.read()


def write_file(filepath, content):
    with open(filepath, "w") as f:
        f.write(content)


def patch_ksud_integration_c(src_dir):
    """Widen the #ifdef CONFIG_KSU_MANUAL_HOOK guard around
    ksu_handle_newfstat_ret / ksu_handle_fstat64_ret so the symbols are
    also defined in SUSFS mode when auto-hook enables the newfstat /
    fstat64 inline hooks."""
    filepath = os.path.join(src_dir, "kernel", "runtime", "ksud_integration.c")
    print(f"[*] Patching {filepath}...")
    if not os.path.exists(filepath):
        print(f"    [FAIL] file not found: {filepath}")
        return False
    content = read_file(filepath)

    # The target block is the *second* `#ifdef CONFIG_KSU_MANUAL_HOOK` in
    # the file (the first one is the hook-type #elif chain at ~line 119).
    # We anchor on the comment that immediately follows it to make the
    # match unique to the newfstat/fstat64 definition block.
    old = (
        "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
        "\n"
        "// NOTE: https://github.com/tiann/KernelSU/commit/df640917d11dd0eff1b34ea53ec3c0dc49667002\n"
        "// - added 260110, seems needed for A16 QPR 3\n"
    )
    new = (
        "#if defined(CONFIG_KSU_MANUAL_HOOK) || \\\n"
        "    (defined(CONFIG_KSU_SUSFS) && \\\n"
        "     (defined(KSU_HOOK_AUTO_NEWFSTAT_HOOK) || \\\n"
        "      defined(KSU_HOOK_AUTO_FSTAT64_HOOK)))\n"
        "/* coexist: original guard was #ifdef CONFIG_KSU_MANUAL_HOOK.\n"
        " * Widened so that in SUSFS mode (CONFIG_KSU_SUSFS=y) the\n"
        " * ksu_handle_newfstat_ret / ksu_handle_fstat64_ret symbols are\n"
        " * also emitted when auto_hook_detect.mk has defined\n"
        " * KSU_HOOK_AUTO_NEWFSTAT_HOOK / KSU_HOOK_AUTO_FSTAT64_HOOK\n"
        " * (i.e. 50_add_susfs patch did not insert those *_ret calls\n"
        " * into fs/stat.c, so auto_hook.c provides inline-hook callbacks\n"
        " * that extern-reference these symbols). All dependencies\n"
        " * (ksu_init_rc_hook_inactive, is_init, is_init_rc,\n"
        " * load_module_rc_once, ksu_rc_len, module_rc_len) are available\n"
        " * in SUSFS mode too. */\n"
        "\n"
        "// NOTE: https://github.com/tiann/KernelSU/commit/df640917d11dd0eff1b34ea53ec3c0dc49667002\n"
        "// - added 260110, seems needed for A16 QPR 3\n"
    )

    # Idempotent: already widened
    if "Widened so that in SUSFS mode (CONFIG_KSU_SUSFS=y) the" in content:
        print("    [SKIP] newfstat_ret/fstat64_ret guard already widened")
        return True

    if old not in content:
        print("    [FAIL] newfstat_ret/fstat64_ret definition block anchor not found")
        print("           (expected '#ifdef CONFIG_KSU_MANUAL_HOOK' followed by")
        print("            the A16 QPR 3 NOTE comment)")
        print("           Please check ReSukiSU auto-hook branch")
        print("           kernel/runtime/ksud_integration.c source")
        return False

    content = content.replace(old, new, 1)
    write_file(filepath, content)
    print("    [OK] widened newfstat_ret/fstat64_ret guard for SUSFS + auto-hook")
    return True


def patch_dispatch_c(src_dir):
    """Make the manager-facing hook-type string distinguish the auto-hook
    branch's SUSFS mode from the main branch's pure SUSFS mode.

    kernel/supercall/dispatch.c do_get_hook_type() returns a hard-coded
    string to the manager:
        #if defined(CONFIG_KSU_TRACEPOINT_HOOK)   -> "Tracepoint Syscall Redirect"
        #elif defined(CONFIG_KSU_MANUAL_HOOK)     -> "Manual"
        #elif defined(CONFIG_KSU_SUSFS)            -> "Inline"
    Because resukisu-auto builds with CONFIG_KSU_SUSFS=y (and no
    CONFIG_KSU_MANUAL_HOOK), the manager always shows "Inline", identical
    to the plain resukisu (main branch SUSFS) build.

    The auto-hook branch differs from main in that its Kbuild SUSFS
    branch includes tools/auto_hook_detect.mk, which defines
    KSU_HOOK_AUTO_*_HOOK macros via ccflags-y (globally visible to every
    .c, including dispatch.c) whenever the kernel tree lacks the
    corresponding ksu_handle_* source call. We use any of those macros as
    a compile-time marker of "this is an auto-hook SUSFS build" and
    report "Auto-hook" instead of "Inline" for that case.

    Pure-SUSFS builds on the main branch never include auto_hook_detect.mk
    in the SUSFS branch, so none of the KSU_HOOK_AUTO_*_HOOK macros are
    defined and the string stays "Inline" exactly as before.
    """
    filepath = os.path.join(src_dir, "kernel", "supercall", "dispatch.c")
    print(f"[*] Patching {filepath}...")
    if not os.path.exists(filepath):
        print(f"    [FAIL] file not found: {filepath}")
        return False
    content = read_file(filepath)

    old = (
        '#elif defined(CONFIG_KSU_SUSFS)\n'
        '    const char *type = "Inline";\n'
    )
    new = (
        '#elif defined(CONFIG_KSU_SUSFS)\n'
        '    /* coexist: distinguish auto-hook branch SUSFS mode from main\n'
        '     * branch pure SUSFS mode. The auto-hook branch Kbuild SUSFS\n'
        '     * branch includes tools/auto_hook_detect.mk, which defines\n'
        '     * KSU_HOOK_AUTO_*_HOOK macros via ccflags-y (globally visible)\n'
        '     when the kernel tree lacks the corresponding ksu_handle_*\n'
        '     * source call. main branch pure SUSFS never includes\n'
        '     * auto_hook_detect.mk in the SUSFS branch, so none of those\n'
        '     * macros are defined and the string stays "Inline". */\n'
        '  #if defined(KSU_HOOK_AUTO_SETUID_HOOK) || \\\n'
        '      defined(KSU_HOOK_AUTO_INITRC_HOOK) || \\\n'
        '      defined(KSU_HOOK_AUTO_INPUT_HOOK) || \\\n'
        '      defined(KSU_HOOK_AUTO_REBOOT_HOOK) || \\\n'
        '      defined(KSU_HOOK_AUTO_EXECVE_HOOK) || \\\n'
        '      defined(KSU_HOOK_AUTO_FACCESSAT_HOOK) || \\\n'
        '      defined(KSU_HOOK_AUTO_STAT_HOOK) || \\\n'
        '      defined(KSU_HOOK_AUTO_NEWFSTAT_HOOK) || \\\n'
        '      defined(KSU_HOOK_AUTO_FSTAT64_HOOK)\n'
        '    const char *type = "Auto-hook";\n'
        '  #else\n'
        '    const char *type = "Inline";\n'
        '  #endif\n'
    )

    # Idempotent: already patched
    if 'const char *type = "Auto-hook";' in content:
        print('    [SKIP] dispatch.c hook-type string already distinguishes Auto-hook')
        return True

    if old not in content:
        print('    [FAIL] SUSFS hook-type string ("Inline") not found in dispatch.c')
        print("           Please check ReSukiSU auto-hook branch")
        print("           kernel/supercall/dispatch.c source")
        return False

    content = content.replace(old, new, 1)
    write_file(filepath, content)
    print('    [OK] dispatch.c SUSFS hook-type now reports "Auto-hook" when auto_hook_detect is active')
    return True


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <resukisu_kernel_dir>")
        sys.exit(1)
    src_dir = sys.argv[1]
    if not os.path.isdir(src_dir):
        print(f"[FAIL] not a directory: {src_dir}")
        sys.exit(1)

    ok = True
    ok = patch_ksud_integration_c(src_dir) and ok
    ok = patch_dispatch_c(src_dir) and ok
    if ok:
        print("[*] Done: ReSukiSU auto-hook symbol fix applied successfully")
    else:
        print("[*] Done: some patches FAILED, please review above")
        sys.exit(1)


if __name__ == "__main__":
    main()
