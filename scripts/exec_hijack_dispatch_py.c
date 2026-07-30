#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <unistd.h>
#include <string.h>
#include <spawn.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdarg.h>

/*
visit https://sswiki.sgs.com.tw:8090/pages/viewpage.action?pageId=91464841 for more information
*/

#define PATH_PREFIX "/tmp/"
#define PATH_SUFFIX "_filter_dispatch.sh"
#define SLASH "/"

#define _STR(x) #x
#define STR(x) _STR(x)

#ifndef PYTHON_VER
#define PYTHON_VER python3
#endif

#ifndef JOBNAME
#define JOBNAME
#endif

#define SHEBANG_LEN (128)
#define MAX_ARGC    (99)

static const char* TARGET_PYTHON_PATH[] = {
    STR(PYTHON_VER),
    "/usr/bin/" STR(PYTHON_VER),
    NULL
};

static const char* CUSTOM_SCRIPT_PATH = PATH_PREFIX STR(JOBNAME) SLASH STR(PYTHON_VER) PATH_SUFFIX;

typedef int (*execve_func)(const char*, char* const[], char* const[]);
typedef int (*execvp_func)(const char*, char* const[]);
typedef int (*execv_func)(const char*, char* const[]);
typedef void (*pHandler_t)(void);

static execve_func orig_execve = NULL;
static execvp_func orig_execvp = NULL;
static execv_func orig_execv = NULL;

// 初始化函数：加载时自动获取原始函数地址
__attribute__((constructor)) static void init()
{
    orig_execve = (execve_func)dlsym(RTLD_NEXT, "execve");
    orig_execvp = (execvp_func)dlsym(RTLD_NEXT, "execvp");
    orig_execv = (execv_func)dlsym(RTLD_NEXT, "execv");
}

// 判断是否为需要劫持的Python路径
static int is_target_python(const char* path)
{
    int i = 0;
    for (i = 0; TARGET_PYTHON_PATH[i] != NULL; i++)
    {
        if (strcmp(path, TARGET_PYTHON_PATH[i]) == 0)
        {
            return 1;
        }
    }
    return 0;
}

static int dispatch_exec(const char *path,  char* const argv[], char* const envp[], pHandler_t handle, int envMode)
{
    if (!handle)
    {
        fprintf(stderr, "no handle, please check!!!\n");
    }
    int i = 0;
    int argc = 0;
    size_t bytes_read = 0;
    FILE *fp = NULL;
    char shebang[SHEBANG_LEN] = {0};
    int flag = 0;
    char *new_argv[MAX_ARGC] = {NULL};

    if (is_target_python(path))
    {
        flag = 1;

        argc = 0;
        while (argv[argc] != NULL)
        {
            argc++;
        }

        new_argv[0] = (char*)CUSTOM_SCRIPT_PATH;
        for (i = 1; i < argc; i++)
        {
            new_argv[i] = argv[i];
        }
        new_argv[argc] = NULL;
    }

    if (strstr(path, ".py") != NULL)
    {
        fp = fopen(path, "r");
        if (fp != NULL)
        {
            if (fgets(shebang, SHEBANG_LEN, fp) != NULL)
            {
                shebang[strcspn(shebang, "\n")] = '\0';
                if (strstr(shebang, STR(PYTHON_VER)) != NULL)
                {
                    flag = 1;

                    argc = 0;
                    while (argv[argc] != NULL)
                    {
                        argc++;
                    }

                    new_argv[0] = (char *)CUSTOM_SCRIPT_PATH;
                    for (i = 1; i < argc + 1; i++)
                    {
                        new_argv[i] = argv[i - 1];
                    }
                    new_argv[argc + 1] = NULL;
                }
            }
            fclose(fp);
        }
    }

    if (envMode)
    {
        execve_func curHandle = (execve_func)handle;
        if (flag)
        {
            return  curHandle(CUSTOM_SCRIPT_PATH, new_argv, envp);
        }
        else
        {
            return curHandle(path, argv, envp);
        }
    }
    else
    {
        execv_func curHandle = (execv_func)handle;
        if (flag)
        {
            return curHandle(CUSTOM_SCRIPT_PATH, new_argv);
        }
        else
        {
            return  curHandle(path, argv);
        }
    }
}

int execve(const char* pathname, char* const argv[], char* const envp[])
{
    return dispatch_exec(pathname, argv, envp, (pHandler_t)orig_execve, 1);
}

int execvp(const char* file, char* const argv[])
{
    return dispatch_exec(file, argv, NULL, (pHandler_t)orig_execvp, 0);
}

int execv(const char* file, char* const argv[])
{
    return dispatch_exec(file, argv, NULL, (pHandler_t)orig_execv, 0);
}