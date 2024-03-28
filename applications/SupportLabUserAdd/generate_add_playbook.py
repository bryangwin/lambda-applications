import yaml
import crypt
import os
import getpass
from ansible.constants import DEFAULT_VAULT_ID_MATCH

# Remember to change path if needed once migrated to head node
USERS_BASE_DIR = "/home/ubuntu/ansible/users"

def get_user_input():
    while True:
        username = input("Enter your desired username: ")
        user_file_path = os.path.join(USERS_BASE_DIR, f"{username}.yml")
        if os.path.exists(user_file_path):
            print(f"A user with the name '{username}' already exists. Please choose a different username.")
            continue

        while True:
            password = getpass.getpass("Enter your desired password: ")
            password_confirmation = getpass.getpass("Confirm your password: ")
            if password == password_confirmation:
                break
            else:
                print("Passwords do not match. Please try again.")
        
        ssh_key = input("Please paste your entire public SSH key: ")
        return username, password, ssh_key

def generate_linux_password(password):
    # Generate a salt
    salt = crypt.mksalt()

    # Hash the password with the salt using the crypt method
    hashed_password = crypt.crypt(password, salt)

    return hashed_password

def generate_playbook(username, hashed_password, ssh_key):
    playbook = {
        'hosts': 'all',
        'become': True,  
        'vars': {
            'new_username': username,
            'new_user_password': hashed_password,
            'users_public_ssh_key': ssh_key
        },
        'tasks': [
            {
                'name': 'Create new user',
                'user': {
                    'name': '{{ new_username }}',
                    'password': '{{ new_user_password }}',
                    'shell': '/bin/bash',
                    'groups': 'sudo',
                    'append': 'yes'
                }
            },
            {
                'name': 'Ensure .ssh directory exists',
                'file': {
                    'path': '/home/{{ new_username }}/.ssh',
                    'state': 'directory',
                    'owner': '{{ new_username }}',
                    'group': '{{ new_username }}',
                    'mode': '0700'
                }
            },
            {
                'name': 'Set authorized key for SSH access using shell command',
                'shell': "echo '{{ users_public_ssh_key }}' >> /home/{{ new_username }}/.ssh/authorized_keys",
                'args': {
                    'creates': '/home/{{ new_username }}/.ssh/authorized_keys'  
                },
            }
        ]
    }
    return playbook


def save_playbook(playbook, username, hashed_password):
    filename = f"{username}.yml"
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
    username, password, ssh_key = get_user_input()
    hashed_password = generate_linux_password(password)
    playbook = generate_playbook(username, hashed_password, ssh_key)
    playbook_filename = save_playbook(playbook, username, hashed_password)
    edit_yaml_file(playbook_filename)
    with open('/tmp/python_script_output.txt', 'w') as f:
        f.write(playbook_filename)


if __name__ == "__main__":
    main()

