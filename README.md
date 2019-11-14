Sparse Checkout
===============

1. Clone the whole repo
2. cd into the repo
3. run "git config core.sparsecheckout true"
4. run "echo <directory_you_want> >> .git/info/sparse-checkout" for each folder you want
5. run "git read-tree -m -u HEAD"

scripting_projects
==================

### [dyndns_iptables/](./dyndns_iptables/dyndns_hosts_instructions.txt)

The linux firewall (IPTables) allows connections by IP address. IP addresses change for home users and those traveling around.  Dynect and others have services called Dynamic DNS that gets updated by a client on the user's machine or router.  This script pulls those DNS entries and check them against what is currently in the firewall and then updates the firewall if necessary.

### [route53_automation/](./route53_automation/awscli_on_pfsense.md)

Mostly just automating updating the IP address in a DNS record on Route53 (Amazon AWS DNS service).  I use it as a way to have my router update the DNS record I use to find my router when I'm too cheap to pay for a static IP or if it's not offered (as in the case of a residential ISP). Often paired with the IPtables scripts above to allow a network/host to trust an IP that is dynamic (like for VPN or phones at a remote worker's house).

### aws_cli_mfa_tool.sh

Automates using MFA credentials over the AWS CLI.
