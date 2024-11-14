# Kaijiro's install

## Requirements :

```shell
pip install ansible
```


## Usage :
Execute this command to install everything (Ansible will prompt you for your password) :
```shell
ansible-playbook -v -i localhost, -c local ./complete_install.yml --ask-become-pass
```

## TODO :

- [ ] Install IntelliJ plugins
