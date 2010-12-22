#/usr/bin/ruby
require 'syslog'
require 'net/smtp'
#Script Name:  ssh_mysql.rb
#Purpose:  This script is designed to check the current system to see if there
#is a current ssh connection to the database server
#and if not, to restart that connection
#if the connection can't be started after 10 minutes
#then an email should be sent to the addresses listed
#this script would be set up to run on a cron job on the server
#for once every 5 minutes
$server_name = "servername"
$server_address = "#{$server_name}.example.com"

email_recipient = "admin@example.com"


def send_email(to,opts={})
  opts[:server]      ||= 'inbound.smtp.example.com'
  opts[:from]        ||= "#{$server_name}@#{$server_address}"
  opts[:from_alias]  ||= "#{$server_name} SSH Database Connection"
  opts[:subject]     ||= "#{$server_name} SSH Database Connection ERROR"
  opts[:body]        ||= "The ssh database connection is failing for #{$server_name}!"
 
  msg = <<END_OF_MESSAGE
From: #{opts[:from_alias]} <#{opts[:from]}>
To: <#{to}>
Subject: #{opts[:subject]}
 
#{opts[:body]}
END_OF_MESSAGE
 
  Net::SMTP.start(opts[:server]) do |smtp|
    smtp.send_message msg, opts[:from], to
  end
end

def log(message, critical=false)
  puts message
  Syslog.open("ssh_database_connection")
  unless critical
    Syslog.notice(message)
  else
    Syslog.crit(message)
  end
  Syslog.close
end

#check to see if the ssh connection is active, if so, log it and end
#need to run a ps aux and check for this command:
#ssh -f -N -L 9999:localhost:3306 
ssh_ps = "ssh -f -N -L 9999:localhost:3306"

#this command needs to be modified for the specific server
full_ssh_command = 'su - admin -c "ssh -f -N -L 9999:localhost:3306 remote_user@servername.example.com"'

ps_return = `ps aux`

if ps_return.include?(ssh_ps)
  log("SSH connection for database OK")
  exit
end


#this is default to two minutes
wait_time = 10
attempt_count = 0
while !ps_return.include?(ssh_ps)
  
  if attempt_count > 0
    #wait a while
    puts "Sleeping"
    sleep wait_time
    puts "Done sleeping"
  end
    
  if attempt_count > 5
    #need to send an email and increase the time that we wait to 15 minutes between connections
    send_email(email_recipient)
    log("Can't connect to database after 5 attempts, email dispatched", true)
    wait_time = 900
  else
    log("Datbase is not connnected via ssh, attempting reconnection...", true)
  end
  
  #try to reconnect to the server
  system(full_ssh_command)
  
  #need to update the ps check
  ps_return = `ps aux`
  attempt_count = attempt_count + 1
end
#log that its working
log("SSH connection for database reconnected")



