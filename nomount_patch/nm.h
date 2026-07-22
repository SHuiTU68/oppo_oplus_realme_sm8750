/* --- ARCH --- */
#if defined(__aarch64__)
    #define SYS_GETCWD     17
    #define SYS_IOCTL      29
    #define SYS_OPENAT     56
    #define SYS_CLOSE      57
    #define SYS_READ       63
    #define SYS_WRITE      64
    #define SYS_EXIT       93

    __attribute__((always_inline)) static inline long sys1(long n, long a) {
        register long x8 asm("x8") = n; register long x0 asm("x0") = a;
        __asm__ __volatile__("svc 0" : "+r"(x0) : "r"(x8) : "memory", "cc");
        return x0;
    }
    __attribute__((always_inline)) static inline long sys3(long n, long a, long b, long c) {
        register long x8 asm("x8") = n; register long x0 asm("x0") = a; register long x1 asm("x1") = b; register long x2 asm("x2") = c;
        __asm__ __volatile__("svc 0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2) : "memory", "cc");
        return x0;
    }
    __attribute__((always_inline)) static inline long sys4(long n, long a, long b, long c, long d) {
        register long x8 asm("x8") = n; register long x0 asm("x0") = a;
        register long x1 asm("x1") = b; register long x2 asm("x2") = c; register long x3 asm("x3") = d;
        __asm__ __volatile__("svc 0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2), "r"(x3) : "memory", "cc");
        return x0;
    }
    __asm__( ".global _start\n" ".type _start, %function\n" "_start:\n" "mov x0, sp\n" "b c_main\n" );

#elif defined(__arm__)
    #define SYS_EXIT       1
    #define SYS_READ       3
    #define SYS_WRITE      4
    #define SYS_CLOSE      6
    #define SYS_IOCTL      54
    #define SYS_GETCWD     183
    #define SYS_OPENAT     322

    __attribute__((always_inline)) static inline long sys1(long n, long a) {
        register long r7 asm("r7") = n; register long r0 asm("r0") = a;
        __asm__ __volatile__("svc 0" : "+r"(r0) : "r"(r7) : "memory", "cc");
        return r0;
    }
    __attribute__((always_inline)) static inline long sys3(long n, long a, long b, long c) {
        register long r7 asm("r7") = n; register long r0 asm("r0") = a; register long r1 asm("r1") = b; register long r2 asm("r2") = c;
        __asm__ __volatile__("svc 0" : "+r"(r0) : "r"(r7), "r"(r1), "r"(r2) : "memory", "cc");
        return r0;
    }
    __attribute__((always_inline)) static inline long sys4(long n, long a, long b, long c, long d) {
        register long r7 asm("r7") = n; register long r0 asm("r0") = a;
        register long r1 asm("r1") = b; register long r2 asm("r2") = c; register long r3 asm("r3") = d;
        __asm__ __volatile__("svc 0" : "+r"(r0) : "r"(r7), "r"(r1), "r"(r2), "r"(r3) : "memory", "cc");
        return r0;
    }
    __asm__( ".global _start\n" ".type _start, %function\n" "_start:\n" "mov r0, sp\n" "b c_main\n");

#elif defined(__x86_64__)
    #define SYS_READ       0
    #define SYS_WRITE      1
    #define SYS_CLOSE      3
    #define SYS_IOCTL      16
    #define SYS_EXIT       60
    #define SYS_GETCWD     79
    #define SYS_OPENAT     257

    __attribute__((always_inline)) static inline long sys1(long n, long a) {
        long ret; __asm__ __volatile__("syscall" : "=a"(ret) : "a"(n), "D"(a) : "rcx", "r11", "memory", "cc");
        return ret;
    }
    __attribute__((always_inline)) static inline long sys3(long n, long a, long b, long c) {
        long ret; __asm__ __volatile__("syscall" : "=a"(ret) : "a"(n), "D"(a), "S"(b), "d"(c) : "rcx", "r11", "memory", "cc");
        return ret;
    }
    __attribute__((always_inline)) static inline long sys4(long n, long a, long b, long c, long d) {
        long ret; register long r10 asm("r10") = d;
        __asm__ __volatile__("syscall" : "=a"(ret) : "a"(n), "D"(a), "S"(b), "d"(c), "r"(r10) : "rcx", "r11", "memory", "cc");
        return ret;
    }
    __asm__( ".global _start\n" ".type _start, @function\n" "_start:\n" "mov %rsp, %rdi\n" "jmp c_main\n" );

#else
    #error "Arch not supported"
#endif

/* --- IOCTL DEFS --- */
#define O_RDWR 02
#define AT_FDCWD -100
#define PATH_MAX 4096

#define NOMOUNT_IOCTL_MAGIC 'N'
#define NOMOUNT_MAGIC_SIG 0x4E4F4D4F554E54ULL

#define _IOC(dir, type, nr, size) (((dir) << 30) | ((size) << 16) | ((type) << 8) | ((nr) << 0))
#define NM_ADD_RULE  _IOC(1U, NOMOUNT_IOCTL_MAGIC, 1, sizeof(struct nm_api_payload))
#define NM_DEL_RULE  _IOC(1U, NOMOUNT_IOCTL_MAGIC, 2, sizeof(struct nm_api_payload))
#define NM_CLEAR_ALL _IOC(0U, NOMOUNT_IOCTL_MAGIC, 3, 0)
#define NM_ADD_UID   _IOC(1U, NOMOUNT_IOCTL_MAGIC, 4, sizeof(struct nm_api_payload))
#define NM_DEL_UID   _IOC(1U, NOMOUNT_IOCTL_MAGIC, 5, sizeof(struct nm_api_payload))
#define NM_GET_VER   _IOC(2U, NOMOUNT_IOCTL_MAGIC, 6, sizeof(struct nm_api_payload))
#define NM_GET_RULE  _IOC(1U, NOMOUNT_IOCTL_MAGIC, 7, sizeof(struct nm_api_payload))

struct nm_api_payload {
    unsigned long long magic_sig;
    unsigned int flags;
    unsigned int uid;
    unsigned int version;
    unsigned short v_len;
    unsigned short r_len;
    char paths[PATH_MAX * 2]; 
};

static struct nm_api_payload payload;
static char cwd_buf[PATH_MAX];

/* --- HELPERS --- */
static void print_str(const char *s) {
    long len = 0;
    while (s[len]) len++;
    sys3(SYS_WRITE, 1, (long)s, len);
}

/* path resolution */
static char* resolve_path(char *p, const char *cwd, const char *rel) {
    if (cwd && *rel != '/') {
        while (*cwd) *p++ = *cwd++;
        *p++ = '/'; /* Linux VFS treats "//" exactly as "/" */
    }
    while ((*p++ = *rel++));
    return p - 1; /* Points exactly to '\0' */
}
