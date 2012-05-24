Sparse Checkout
===============

1. Clone the whole repo
2. cd into the repo
3. run "git config core.sparsecheckout true"
4. run "echo <directory_you_want> >> .git/info/sparse-checkout" for each folder you want
5. run "git read-tree -m -u HEAD"

scripting_projects
==================

dyndns_iptables/
	The linux firewall (IPTables) allows connections by IP address. IP addresses change for home users and those traveling around.  Dynect and others have services called Dynamic DNS that gets updated by a client on the user's machine or router.  This script pulls those DNS entries and check them against what is currently in the firewall and then updates the firewall if necessary.


