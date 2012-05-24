#!/usr/bin/python

import os
import csv
import socket

iptables_file = '/etc/iptables.up.rules'
csv_file = './dyndns_hosts.csv'
lock_file = './dyndns_hosts.lock'
something_changed = False
host_col = 0
ip_col = 1

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'

def readHostList():
	"""Return host_list (dictionary) stored in CSV file."""
	reader = csv.reader(open(csv_file, 'rb'), delimiter=',', quotechar='"')
	host_list = {}
	for row in reader:
		host_list[row[host_col]] = row[ip_col]
        return host_list

def getTextOutput(cmd):
        """Return (status, output) of executing cmd in a shell."""
        pipe = os.popen('{ ' + cmd + '; } 2>&1', 'r')
        pipe = os.popen(cmd + ' 2>&1', 'r')
        text = pipe.read()
        if text[-1:] == '\n': text = text[:-1]
        return text

def saveHostList():
	"""save host_list (dictionary) to CSV file."""
	writer = csv.writer(open(csv_file, 'wb'), delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
	for hostname in host_list:
		writer.writerow([hostname,host_list[hostname]])

def updateIPtablesEntry(hostname,ip_address):
	"""update single entry in IPTables config file."""
	# make sure the address is valid
	if addressIsValid(ip_address):
		#print "updating iptables file entry for " + hostname + " to " + ip_address #DEBUG
		pass
	else:
		print bcolors.FAIL + "IP address (" + ip_address + ") is invalid. Cannot update iptables" + bcolors.ENDC
		return False

	# find out where in the file the comment for the rule is located
	comment_line = getTextOutput("grep -n '# " + hostname + "' " + iptables_file + " | cut -d':' -f1")

	# check to make sure the comment was found
	if comment_line == '':
		print bcolors.WARNING + "Unable to locate entry for " + hostname + " in the file " + iptables_file + bcolors.ENDC
		print bcolors.WARNING + "If there is a rule already it needs to have a comment line above it so I can find it." + bcolors.ENDC
		print bcolors.WARNING + "The comment line should look like this: '# " + hostname + "'" + bcolors.ENDC
		print bcolors.WARNING + "If you are using webmin then it would be just '" + hostname + "'" + bcolors.ENDC
		return False
	else:
		#print "comment is located at line #" + comment_line #DEBUG
		pass
	
	# the rule line should be right below the comment
	rule_line = int(float(comment_line)) + 1
	#print "rule is located at line #" + str(rule_line) #DEBUG

	# replace the rule line in the file with a new one
	rule = "-A INPUT -s "+ ip_address + " -j ACCEPT"
	os.system("sed -i '" + str(rule_line) + "s/.*/" + rule + "/' " + iptables_file)
	
	# let the script know to reload iptables
	something_changed = True

def addressIsValid(ip_address):
	try:
                socket.inet_aton(cur_dyndns)
                # address is valid
                return True
        except socket.error:
                # address invalid
		return False

def reloadIptables():
	os.system("iptables-restore < " + iptables_file)

# make sure this is not already running
if os.path.exists(lock_file):
	print  bcolors.FAIL + "This utility seems to be already running." + bcolors.ENDC
	print  bcolors.FAIL + "If this is not the case delete the file "+ lock_file + " and try running the utility again." + bcolors.ENDC
	exit()
else:
	os.system("touch " + lock_file)

# Read in the hosts
host_list = readHostList()

for hostname in host_list:
	# pull the addresses
	cur_dyndns = getTextOutput("host " + hostname + " | cut -d ' ' -f4")
	last_dyndns = host_list[hostname]
	#print "The IP address on file for " + hostname + " is " + last_dyndns #DEBUG
	
	# ensure the new one is valid
	if addressIsValid(cur_dyndns):
		#print "The current IP address for " + hostname + " is " + cur_dyndns #DEBUG
		pass
	else:
		print bcolors.WARNING + "Unable to resolve " + hostname + ". Keeping old IP address." + bcolors.ENDC
                cur_dyndns = last_dyndns

	# check to see if they match
	if cur_dyndns != last_dyndns:
		print "Changing address for " + hostname + " from " + last_dyndns + " to " + cur_dyndns
		host_list[hostname] = cur_dyndns
		updateIPtablesEntry(hostname,host_list[hostname])
	else:
		#print "there was no change in address for " + hostname + ". It will remain " + host_list[hostname] + "." #DEBUG
		pass

if something_changed:
	#print "saving host list back to CSV file" #DEBUG
	saveHostList()
	print bcolors.OKGREEN + "Reloading iptables to update" + bcolors.ENDC
	reloadIptables()

# unlock the utility
os.remove(lock_file)

# set color to default
print bcolors.ENDC + " "
