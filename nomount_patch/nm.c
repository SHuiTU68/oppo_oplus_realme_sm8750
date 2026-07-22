/*
 * nm.c - NoMount CLI Userspace Tool
 */
#include "nm.h"

/* --- MAIN --- */
__attribute__((noreturn, used))
void c_main(long *sp) {
    long argc = *sp;
    char **argv = (char **)(sp + 1);
    int exit_code = 1;
    int fd = -1;

    if (argc < 2) {
        print_str("nm <command>\n");
        goto do_exit;
    }

    fd = sys4(SYS_OPENAT, AT_FDCWD, (long)"/dev/nomount", O_RDWR, 0);
    if (fd < 0) { exit_code = 2; goto do_exit; }

    char cmd = argv[1][0];
    for (int i = 0; i < sizeof(payload); i++) ((char*)&payload)[i] = 0;
    payload.magic_sig = NOMOUNT_MAGIC_SIG;

    if (cmd == 'a' || cmd == 'd' || cmd == 'w') {
        int step = 1 + (cmd == 'a');
        if (argc < 2 + step) { exit_code = 0; goto do_exit; }

        const char *cwd = (sys3(SYS_GETCWD, (long)cwd_buf, PATH_MAX, 0) > 0) ? cwd_buf : "/";
        int target_cmd = (cmd == 'd') ? NM_DEL_RULE : NM_ADD_RULE;
        exit_code = 0;

        for (int i = 2; i + step - 1 < argc; i += step) {
            char *v_end = resolve_path(payload.paths, cwd, argv[i]);
            int v_len = v_end - payload.paths;
            if (!v_len) { exit_code |= 3; continue; }

            int r_len = 0;
            if (cmd == 'a') {
                char *r_end = resolve_path(payload.paths + v_len + 1, cwd, argv[i+1]);
                r_len = r_end - (payload.paths + v_len + 1);
                if (!r_len) { exit_code |= 3; continue; }
            }

            payload.v_len = v_len;
            payload.r_len = r_len;
            payload.flags = (cmd == 'w') ? 8 : 0; /* NM_FLAG_WHITEOUT = (1 << 3) */

            if (sys3(SYS_IOCTL, fd, target_cmd, (long)&payload) < 0) exit_code |= 1;
        }
        goto do_exit;

    } else if (cmd == 'b' || cmd == 'u') {
        if (argc < 3) goto do_exit;
        unsigned int uid = 0; const char *s = argv[2];
        while (*s) uid = (uid << 3) + (uid << 1) + (*s++ - '0');

        payload.uid = uid;
        int target_cmd = (cmd == 'b') ? NM_ADD_UID : NM_DEL_UID;
        exit_code = (sys3(SYS_IOCTL, fd, target_cmd, (long)&payload) < 0);
        goto do_exit;

    } else if (cmd == 'c') {
        exit_code = (sys3(SYS_IOCTL, fd, NM_CLEAR_ALL, 0) < 0);
        goto do_exit;

    } else if (cmd == 'v') {
        if (sys3(SYS_IOCTL, fd, NM_GET_VER, (long)&payload) == 0) { 
            unsigned int v = payload.version; 
            char v_str[4] = {0};
            unsigned char tens = ((v << 7) + (v << 6) + (v << 3) + (v << 2) + v) >> 11;
            v = v - ((tens << 3) + (tens << 1));
            v_str[0] = tens + '0'; v_str[1] = v + '0'; v_str[2] = '\n';
            print_str(v_str);
            exit_code = 0; 
        }
        goto do_exit;

    } else if (cmd == 'l') {
        int is_json = (argc > 2 && argv[2][0] == 'j');
        int offset = 2;
        if (is_json) print_str("[\n");

        int idx = 0;
        while (1) {
            payload.magic_sig = NOMOUNT_MAGIC_SIG;
            payload.flags = idx;
            if (sys3(SYS_IOCTL, fd, NM_GET_RULE, (long)&payload) < 0) break;

            char *v = payload.paths;
            char *r = payload.paths + payload.v_len + 1;
            int is_whiteout = (payload.flags & 8);

            if (is_json) {
                print_str((const char *)",\n  {\n    \"virtual\": \"" + offset); offset = 0;
                print_str(v);
                if (is_whiteout) {
                    print_str("\",\n    \"whiteout\": true\n  }");
                } else {
                    print_str("\",\n    \"real\": \""); print_str(r); print_str("\"\n  }");
                }
            } else {
                print_str(v);
                if (is_whiteout) {
                    print_str(" (whiteout)\n");
                } else {
                    print_str(" -> "); print_str(r); print_str("\n");
                }
            }
            idx++;
        }

        if (is_json) print_str("\n]\n");
        exit_code = 0;
    }

do_exit:
    sys1(SYS_EXIT, exit_code);
    __builtin_unreachable();
}
