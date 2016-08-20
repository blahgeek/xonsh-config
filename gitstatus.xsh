# change those symbols to whatever you prefer
def _gitstatus():
    import re
    from subprocess import Popen, PIPE
    symbols = {'ahead of': '↑·', 'behind': '↓·', 'prehash': ':'}

    def get_tag_or_hash():
        cmd = Popen(['git', 'describe', '--exact-match'], stdout=PIPE, stderr=PIPE)
        so, se = cmd.communicate()
        tag = '%s' % so.decode('utf-8').strip()

        if tag:
            return tag
        else:
            cmd = Popen(['git', 'rev-parse', '--short', 'HEAD'], stdout=PIPE, stderr=PIPE)
            so, se = cmd.communicate()
            hash_name = '%s' % so.decode('utf-8').strip()
            return ''.join([symbols['prehash'], hash_name])

    def get_stash():
        cmd = Popen(['git', 'rev-parse', '--git-dir'], stdout=PIPE, stderr=PIPE)
        so, se = cmd.communicate()
        stash_file = '%s%s' % (so.decode('utf-8').rstrip(), '/logs/refs/stash')

        try:
            with open(stash_file) as f:
                return sum(1 for _ in f)
        except IOError:
            return 0

    # `git status --porcelain --branch` can collect all information
    # branch, remote_branch, untracked, staged, changed, conflicts, ahead, behind
    po = Popen(['git', 'status', '--porcelain', '--branch'], env={'LC_ALL': 'C'}, stdout=PIPE, stderr=PIPE)
    stdout, stderr = po.communicate()
    if po.returncode != 0:
        return None

    # collect git status information
    untracked, staged, changed, conflicts = ([], [], [], [])
    num_ahead, num_behind = 0, 0
    ahead, behind = '', ''
    branch = ''
    remote = ''
    status = [(line[0], line[1], line[2:]) for line in stdout.decode('utf-8').splitlines()]
    for st in status:
        if st[0] == '#' and st[1] == '#':
            if re.search('Initial commit on', st[2]):
                branch = st[2].split(' ')[-1]
            elif re.search('no branch', st[2]):  # detached status
                branch = get_tag_or_hash()
            elif len(st[2].strip().split('...')) == 1:
                branch = st[2].strip()
            else:
                # current and remote branch info
                branch, rest = st[2].strip().split('...')
                if len(rest.split(' ')) == 1:
                    # remote_branch = rest.split(' ')[0]
                    pass
                else:
                    # ahead or behind
                    divergence = ' '.join(rest.split(' ')[1:])
                    divergence = divergence.lstrip('[').rstrip(']')
                    for div in divergence.split(', '):
                        if 'ahead' in div:
                            num_ahead = int(div[len('ahead '):].strip())
                            ahead = '%s%s' % (symbols['ahead of'], num_ahead)
                        elif 'behind' in div:
                            num_behind = int(div[len('behind '):].strip())
                            behind = '%s%s' % (symbols['behind'], num_behind)
                    remote = ''.join([behind, ahead])
        elif st[0] == '?' and st[1] == '?':
            untracked.append(st)
        else:
            if st[1] == 'M':
                changed.append(st)
            if st[0] == 'U':
                conflicts.append(st)
            elif st[0] != ' ':
                staged.append(st)

    stashed = get_stash()
    if not changed and not staged and not conflicts and not untracked and not stashed:
        clean = 1
    else:
        clean = 0

    # if remote == "":
    #     remote = '.'

    return branch, remote, len(staged), len(conflicts), len(changed), len(untracked), stashed, clean


def _gitprompt():
    # Default values for the appearance of the prompt. Configure at will.
    GIT_PROMPT_BRANCH    = "{CYAN}"
    GIT_PROMPT_STAGED    = "{RED}●"
    GIT_PROMPT_CONFLICTS = "{RED}×"
    GIT_PROMPT_CHANGED   = "{BLUE}+"
    GIT_PROMPT_UNTRACKED = "…"
    GIT_PROMPT_STASHED   = "⚑"
    GIT_PROMPT_CLEAN     = "{BOLD_GREEN}✓"

    gitstatus = _gitstatus()
    if gitstatus is None:
        return None
    branch, remote, staged, conflicts, changed, untracked, stashed, clean = gitstatus

    ret = '['
    ret += GIT_PROMPT_BRANCH + branch
    if remote:
        ret += ' ' + remote
    ret += '|'
    if staged > 0:
        ret += GIT_PROMPT_STAGED + str(staged) + '{NO_COLOR}'
    if conflicts > 0:
        ret += GIT_PROMPT_CONFLICTS + str(conflicts) + '{NO_COLOR}'
    if changed > 0:
        ret += GIT_PROMPT_CHANGED + str(changed) + '{NO_COLOR}'
    if untracked > 0:
        ret += GIT_PROMPT_UNTRACKED + str(untracked) + '{NO_COLOR}'
    if stashed > 0:
        ret += GIT_PROMPT_STASHED + str(stashed) + '{NO_COLOR}'
    if clean:
        ret += GIT_PROMPT_CLEAN + '{NO_COLOR}'
    ret += ']'

    return ret

$FORMATTER_DICT['_gitprompt'] = _gitprompt
