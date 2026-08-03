import os, sys

fixes = []

# 1. confdata.c: conf_errors 重复定义
f = 'scripts/kconfig/confdata.c'
if os.path.isfile(f):
    with open(f) as fh:
        lines = fh.readlines()
    count = sum(1 for l in lines if l.strip().startswith('bool conf_errors(void)'))
    if count > 1:
        new_lines = []
        in_dup = False
        dup_cnt = 0
        for l in lines:
            if l.strip().startswith('bool conf_errors(void)'):
                dup_cnt += 1
                if dup_cnt > 1:
                    in_dup = True
                    continue
            if in_dup:
                if l.strip() == '}':
                    in_dup = False
                    continue
                continue
            new_lines.append(l)
        with open(f, 'w') as fh:
            fh.writelines(new_lines)
        fixes.append('confdata.c: removed duplicate conf_errors')

# 2. symbol.c: sym_dep_errors 重复定义 + gs 缺失声明
f = 'scripts/kconfig/symbol.c'
if os.path.isfile(f):
    with open(f) as fh:
        content = fh.read()
        lines = content.split('\n')

    # 2a. 修复 sym_dep_errors 重复定义
    count = sum(1 for l in lines if l.strip().startswith('bool sym_dep_errors(void)'))
    if count > 1:
        new_lines = []
        in_dup = False
        dup_cnt = 0
        for l in lines:
            stripped = l.strip()
            if stripped.startswith('bool sym_dep_errors(void)'):
                dup_cnt += 1
                if dup_cnt > 1:
                    in_dup = True
                    continue
            if in_dup:
                if stripped == '}':
                    in_dup = False
                    continue
                continue
            new_lines.append(l)
        lines = new_lines
        fixes.append('symbol.c: removed duplicate sym_dep_errors')

    # 2b. 修复 gs 缺失声明
    has_gs_usage = any('str_get(&gs)' in l or 'str_free(&gs)' in l for l in lines)
    has_gs_decl = any('struct gstr gs' in l for l in lines)
    if has_gs_usage and not has_gs_decl:
        for i, l in enumerate(lines):
            if 'str_get(&gs)' in l or 'str_free(&gs)' in l:
                brace_pos = -1
                for j in range(i-1, max(i-20, 0), -1):
                    if '{' in lines[j]:
                        brace_pos = j
                        break
                if brace_pos >= 0:
                    indent = ' ' * 4
                    lines.insert(brace_pos + 1, indent + 'struct gstr gs;\n')
                    fixes.append('symbol.c: added missing struct gstr gs declaration')
                break

    with open(f, 'w') as fh:
        fh.write('\n'.join(lines))
        if not lines[-1].endswith('\n'):
            fh.write('\n')

if fixes:
    print('[INFO] 修复完成: ' + '; '.join(fixes))
else:
    print('[INFO] 未发现需要修复的重复定义')