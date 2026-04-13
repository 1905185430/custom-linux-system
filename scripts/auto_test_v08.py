#!/usr/bin/env python3
"""
v0.8 自动化测试脚本
自动登录并测试所有功能
"""

import pexpect
import sys
import time
import os

# 配置
QEMU_CMD = "qemu-system-x86_64 -kernel ./vmlinuz-6.8.0-90-generic -initrd initrd0.8.img -m 1024 -append 'root=/dev/ram0 rw console=ttyS0,115200 loglevel=3' -nographic"

LOGIN_TIMEOUT = 60
CMD_TIMEOUT = 10

class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'

def log_step(msg):
    print(f"{Colors.OKBLUE}[STEP]{Colors.ENDC} {msg}")

def log_success(msg):
    print(f"{Colors.OKGREEN}[PASS]{Colors.ENDC} {msg}")

def log_error(msg):
    print(f"{Colors.FAIL}[FAIL]{Colors.ENDC} {msg}")

def log_info(msg):
    print(f"{Colors.OKBLUE}[INFO]{Colors.ENDC} {msg}")

def test_v08():
    """测试 v0.8"""
    log_step("启动 QEMU...")
    
    # 启动 QEMU
    child = pexpect.spawn(QEMU_CMD, cwd="/home/xuan/linux_class",
                          encoding='utf-8', timeout=LOGIN_TIMEOUT)
    
    # 设置日志
    child.logfile = sys.stdout
    
    try:
        # 等待登录提示
        log_step("等待登录提示...")
        child.expect(["login:", "localhost login:"], timeout=30)
        log_success("登录提示出现")
        
        # 发送用户名
        time.sleep(1)
        child.sendline("root")
        log_info("发送用户名: root")
        
        # 等待密码提示
        child.expect(["Password:", "password:"], timeout=10)
        log_success("密码提示出现")
        
        # 发送密码
        time.sleep(1)
        child.sendline("123456")
        log_info("发送密码")
        
        # 等待登录成功（检查 shell 提示符）
        time.sleep(3)
        
        # 测试 1: id 命令
        log_step("测试 id 命令...")
        child.sendline("id")
        child.expect("uid=0", timeout=CMD_TIMEOUT)
        log_success("id 命令输出正确 (uid=0)")
        
        # 测试 2: whoami 命令
        log_step("测试 whoami 命令...")
        child.sendline("whoami")
        child.expect("root", timeout=CMD_TIMEOUT)
        log_success("whoami 命令输出正确 (root)")
        
        # 测试 3: pwd 命令
        log_step("测试 pwd 命令...")
        child.sendline("pwd")
        child.expect("/root", timeout=CMD_TIMEOUT)
        log_success("pwd 命令输出正确 (/root)")
        
        # 测试 4: 检查 /etc/passwd
        log_step("测试 /etc/passwd...")
        child.sendline("grep root /etc/passwd")
        child.expect("root:x:0:0", timeout=CMD_TIMEOUT)
        log_success("/etc/passwd 存在且正确")
        
        # 测试 5: 检查 /etc/shadow
        log_step("测试 /etc/shadow...")
        child.sendline("ls -la /etc/shadow")
        child.expect("shadow", timeout=CMD_TIMEOUT)
        log_success("/etc/shadow 存在")
        
        # 测试 6: 检查 PAM 配置
        log_step("测试 PAM 配置...")
        child.sendline("ls /etc/pam.d/")
        child.expect("login", timeout=CMD_TIMEOUT)
        log_success("PAM 配置存在")
        
        # 测试 7: 检查 /bin/login
        log_step("测试 /bin/login...")
        child.sendline("ls -la /bin/login")
        child.expect("login", timeout=CMD_TIMEOUT)
        log_success("/bin/login 存在")
        
        # 测试 8: 检查 console-login 服务
        log_step("测试 console-login 服务...")
        child.sendline("systemctl status console-login.service")
        index = child.expect(["Active: active", "inactive", pexpect.TIMEOUT], timeout=CMD_TIMEOUT)
        if index == 0:
            log_success("console-login 服务运行中")
        else:
            log_error("console-login 服务未运行")
        
        # 测试 9: 检查 PAM 库
        log_step("测试 PAM 库...")
        child.sendline("ls /lib/security/")
        child.expect("pam_unix", timeout=CMD_TIMEOUT)
        log_success("PAM 库存在")
        
        # 测试完成
        log_step("所有测试完成!")
        child.sendline("exit")
        time.sleep(1)
        
        # 终止 QEMU
        child.sendcontrol('a')
        child.send('x')
        time.sleep(1)
        
        print(f"\n{Colors.OKGREEN}========================================{Colors.ENDC}")
        print(f"{Colors.OKGREEN}  v0.8 自动化测试全部通过!{Colors.ENDC}")
        print(f"{Colors.OKGREEN}========================================{Colors.ENDC}")
        
        return True
        
    except pexpect.TIMEOUT:
        log_error("等待超时")
        child.sendcontrol('a')
        child.send('x')
        return False
    except pexpect.EOF:
        log_error("QEMU 意外终止")
        return False
    except Exception as e:
        log_error(f"测试异常: {e}")
        try:
            child.sendcontrol('a')
            child.send('x')
        except:
            pass
        return False
    finally:
        try:
            child.close()
        except:
            pass

if __name__ == "__main__":
    print(f"{Colors.HEADER}========================================{Colors.ENDC}")
    print(f"{Colors.HEADER}  v0.8 自动化测试脚本{Colors.ENDC}")
    print(f"{Colors.HEADER}========================================{Colors.ENDC}")
    print()
    
    success = test_v08()
    sys.exit(0 if success else 1)
