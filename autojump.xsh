import os
import platform
import functools
import subprocess
from xonsh import dirstack
# from subprocess import call, check_output

def _init_autojump():

    def _get_error_path():
        if platform.system() == "Darwin":
            return os.path.join($HOME, "Library/autojump/errors.log")
        elif "XDG_DATA_HOME" in __xonsh_env__:
            return os.path.join($XDG_DATA_HOME, "autojump/errors.log")
        else:
            return os.path.join($HOME, ".local/share/autojump/errors.log")

    environ = {
        'PATH': ':'.join($PATH),
        'AUTOJUMP_ERROR_PATH': _get_error_path(),
        'AUTOJUMP_SOURCED': '1',
    }

    call = functools.partial(subprocess.call, env=environ)
    check_output = functools.partial(subprocess.check_output, env=environ, universal_newlines=True)

    def _autojump(args, stdin=None):
        if len(args) and args[0][0] == '-' and args[0] != '--':
            return call(['autojump'] + args)
        output = check_output(['autojump'] + args).strip()
        if os.path.isdir(output):
            # TODO: print with color?
            print(output)
            dirstack.cd([output])
        else:
            print('autojump directory {} not found'.format(' '.join(args)))
            print(output)
            print('Try `autojump --help` for more information.')

    aliases['j'] = _autojump

    def _autojump_update():
        call(['autojump', '--add', os.path.abspath('.')])

    $FORMATTER_DICT['_autojump_update'] = _autojump_update
    $PROMPT += '{_autojump_update}'

    def _autojump_completer(prefix, line, begidx, endidx, ctx):
        '''Completes autojump'''
        if line[:2] != 'j ':
            return None
        output = check_output(['autojump', '--complete', prefix])
        return set(output.strip().split('\n'))

    __xonsh_completers__['autojump'] = _autojump_completer

_init_autojump()
del _init_autojump
