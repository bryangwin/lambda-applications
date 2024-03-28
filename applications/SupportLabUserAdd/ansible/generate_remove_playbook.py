import yaml
import crypt
import getpass
from ansible.constants import DEFAULT_VAULT_ID_MATCH

# Remember to change path if needed once migrated to head node
USERS_BASE_DIR = "/home/ubuntu/ansible/users"

def get_user_input():
    username = input("Enter the username you would like to remove from all hosts: ")
    return username

def generate_playbook(username):
    playbook = {
        'hosts': 'all',
        'become': True,
        'vars': {
            'username': username,
        },
        'tasks': [
            {
                'name': 'Remove user',
                'user': {
                    'name': '{{ username }}',
                    'state': 'absent',
                }
            },
            {
                'name': 'Remove user home directory',
                'file': {
                    'path': '/home/{{ username }}',
                    'state': 'absent'
                }
            }
        ]
    }
    return playbook


def save_playbook(playbook, username):
    filename = f"remove_{username}.yml"
    with open(f"{USERS_BASE_DIR}/{filename}", 'w') as file:
        yaml.safe_dump(playbook, file, default_flow_style=False)
    return filename

def edit_yaml_file(playbook_filename):
    # Read the content of the YAML file
    with open(f"{USERS_BASE_DIR}/{playbook_filename}", 'r') as file:
        content = file.readlines()

    # Add "---" at the very top of the file
    content.insert(0, '\n')
    content.insert(0, '- name: Create new user with password and SSH key on Linux Support Lab hosts')
    content.insert(0, '---\n\n')

    # Add 2 spaces to the beginning of each subsequent line
    for i in range(2, len(content)):
        content[i] = '  ' + content[i]

    # Write the modified content back to the file
    with open(f"{USERS_BASE_DIR}/{playbook_filename}", 'w') as file:
        file.writelines(content)


def main():
    username = get_user_input()
    playbook = generate_playbook(username)
    playbook_filename = save_playbook(playbook, username)
    edit_yaml_file(playbook_filename)
    with open('/tmp/python_script_output.txt', 'w') as f:
        f.write(playbook_filename)
if __name__ == "__main__":
    main()

