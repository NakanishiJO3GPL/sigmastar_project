import re
import sys

size_table=[
    "CONFIG_STACK_SIZE_BOOT",
    "CONFIG_STACK_SIZE_ABT",
    "CONFIG_STACK_SIZE_UND",
    "CONFIG_TASK_CUST_STACK_SIZE"
]

def update_stack_size(file_path, should_update):
    if should_update:
        try:
            #### 替换stack size
            with open(file_path, 'r') as file:
                content = file.read()

            for string in size_table:
                print(string)
                # 正则表达式匹配STACK_SIZE字段
                stack_size_pattern = re.compile(r'{}=(0x[0-9A-Fa-f]+)'.format(string))
                match = stack_size_pattern.search(content)
                if match:
                    # 获取当前的数值
                    original_value = int(match.group(1), 16)
                    # 乘以2
                    new_value = original_value * 2
                    # 转换回十六进制格式
                    new_value_hex = format(new_value, 'X')
                    # 替换原内容
                    content = stack_size_pattern.sub(f'{string}=0x{new_value_hex}', content)
                # 写回文件
                with open(file_path, 'w') as file:
                    file.write(content)
            ##### 打开MCU_ASAN
            with open(file_path, 'r') as file:
                lines = file.readlines()  # 读取所有行

            # 正则表达式匹配包含'MCU_SUPPORT'的行
            mcu_support_pattern = re.compile(r'.*CONFIG_RTOS_MCU_ASAN_SUPPORT.*')

            # 检查文件中是否已经有'MCU_SUPPORT'
            if any(mcu_support_pattern.search(line) for line in lines):
                # 使用正则表达式替换包含'MCU_SUPPORT'的行
                new_lines = [mcu_support_pattern.sub('CONFIG_RTOS_MCU_ASAN_SUPPORT=y\n', line) for line in lines]
            else:
                # 如果没有找到，添加'MCU_SUPPORT=y'到文件末尾
                new_lines = lines + ['\nCONFIG_RTOS_MCU_ASAN_SUPPORT=y\n']
            # 写回修改后的内容
            with open(file_path, 'w') as file:
                file.writelines(new_lines)

        except FileNotFoundError:
            print(f"Error: The file '{file_path}' does not exist.")
        except IOError as e:
            print(f"An I/O error occurred: {e.strerror}")
        except Exception as e:
            print(f"An error occurred: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <file_path> <true|false>")
    else:
        file_path = sys.argv[1]
        should_update = sys.argv[2].lower() == 'true'
        update_stack_size(file_path, should_update)