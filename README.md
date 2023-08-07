
# wordpress-backup-and-restore

Ce script bash permet de créer des sauvegardes du répertoire d'installation WordPress ainsi que de la base de données associée.


## Authors

- [@vnambs](https://www.github.com/vnambs)


## Documentation
this project require mailutils just install it from this command
```bash
  sudo apt install mailutils -y
```
now install the others dependecies

```bash
 sudo apt-get update
 sudo apt-get install awscli
 aws --version
 sudo apt-get install python3-pip
```
now configure the aws client from this command line
```bash
  aws configure
```
now you need to fill the
```bash 
  Access key ID
  Secret access key
  Region
```
from your aws s3 buckets.
For further information on awscli read this documentation [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html)


if you want to use another mailsender than mailutils, here there are a lot have fun
[sending mail from command](https://www.digitalocean.com/community/tutorials/send-email-linux-command-line#3-using-the-mutt-command)

## License

[MIT](https://choosealicense.com/licenses/mit/)

