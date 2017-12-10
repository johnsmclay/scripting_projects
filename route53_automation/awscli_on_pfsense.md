# Installing AWSCLI on Pfsense
1. Install packages _cron_ and _sudo_ in the web UI package manager
    - _sudo_ will allow you to run as root so you can install things
    - _cron_ will let you schedule running scripts regularly
1. Use the sudo package to allow yourself to sudo
1. Add an ssh key to your pfsense account
1. `ssh username@routerip` to get into the pfsense shell
1. `sudo su -` to switch to root
1. `python -m ensurepip` installs pip python package manager
1. `pip install --upgrade pip` upgrades pip to current version
1. `pip install awscli` installs the awscli
1. `aws --version` to ensure it installed properly
1. `aws configure` to add credentials.  Be careful with the default zone thing, it doesn't check it and if you put in an invalid one the cli won't work.  Usually you can leave it blank.
    - __NOTE:__ for security reasons, I would make an IAM account that only has access to read and write records for Route53 in the zone you want.  It's safer that way in case someone gains access to your router.
    - here is a decent IAM policy that restricts the user to just reading/writing recordsets in Route53. It will probably be OK for home stuff... but in a business I would definitely put the ARN of the specific hosted zone in "Resource" and maybe even look into locking it down to specific records using conditions.
```
 {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets"
            ],
            "Resource": "*"
        }
    ]
}
```

## General PfSense stuff

PfSense uses /bin/sh as the default shell for root and something else for other accounts. It doesn't have bash by default and some bash scripts will fail on these cut-down default shells.  Also, the only text editor it comes with is vi, which I hate and gives errors when I try to install vim, so I usually install nano.
 - to install bash run `pkg install bash` as root
 - to install nano run `pkg install nano` as root
