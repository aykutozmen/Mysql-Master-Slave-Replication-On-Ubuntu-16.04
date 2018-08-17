#!/bin/bash
clear
echo " +---------------------------------------------------------------------------------------------------------------------+"
echo " |                                                  IMPORTANT NOTES                                                    |"
echo " | This script must be run with maximum privileges. Run with sudo or run it as 'root'.                                 |"
echo " | Before starting step 2 be sure that master server can connect to slave server via SSH                               |"
echo " | This script was written and tested under OS Ubuntu 16.04 with MariaDB-Server 10.0.34                                |"
echo " | This script must be run on the master server in order to work properly.                                             |"
echo " | This script will do:                                                                                                |"
echo " | 1.  Collection Of Servers' Information                                                                              |"
echo " | 2.  SSH Connection Test From Master to Slave Node                                                                   |"
echo " | 3.  Installation of MariaDB-Server on Both Servers                                                                  |"
echo " | 4.  Configuring Mysql On Master Node                                                                                |"
echo " | 5.  Creating Database Users Named 'slave_user' and 'backup_user' on Master Database                                 |"
echo " | 6.  Create Cinder Service API Endpoints For volumev2 And volumev3                                                   |"
echo " | 7.  Collection of Database Names To Be Replicated                                                                   |"
echo " | 8.  Configuring Mysql On Slave Node                                                                                 |"
echo " | 9.  Restarting Both Database Services on Servers In Order To Replication Becomes Up & Running                       |"
echo " +---------------------------------------------------------------------------------------------------------------------+"
echo

while true; do
read -p " > Please enter master node's IP: [Ex. 192.168.1.101] [Default=192.168.1.101]: " Input
	if [ -z $Input ]
	then
		Input="192.168.1.101"
	fi
	
	DotCount=`echo $Input | awk -F"." '{print NF-1}'`
	FirstOctet=`echo $Input | tr "." "\n" | head -1`
	SecondOctet=`echo $Input | tr "." "\n" | head -2 | tail -1`
	ThirdOctet=`echo $Input | tr "." "\n" | head -3 | tail -1`
	FourthOctet=`echo $Input | tr "." "\n" | head -4 | tail -1`
	if [ $DotCount -eq 3 ] && [ $FirstOctet -lt 255 ] && [ $SecondOctet -lt 255 ] && [ $ThirdOctet -lt 255 ] && [ $FourthOctet -lt 255 ] && [ $FirstOctet -gt 0 ] && [ $SecondOctet -ge 0 ] && [ $ThirdOctet -ge 0 ] && [ $FourthOctet -ne 0 ]
	then
		Master_Node_IP=${Input}
		break
	else
		if [ $FourthOctet -ne 0 ]
		then
			echo " > Your IP format is wrong. Last octet can not be zero. Please correct and try again. "
		fi
		
		if [ $FirstOctet -eq 0 ]
		then
			echo " > Your IP format is wrong. First octet can not be zero. Please correct and try again. "
		fi
		
		if [ $FirstOctet -ge 255 ] || [ $SecondOctet -ge 255 ] || [ $ThirdOctet -ge 255 ] || [ $FourthOctet -ge 255 ]
		then
			echo " > Your IP format is wrong. Octets must be less than 255. Please correct and try again. "
		fi	
		
		if [ $FirstOctet -lt 0 ] || [ $SecondOctet -lt 0 ] || [ $ThirdOctet -lt 0 ] || [ $FourthOctet -lt 0 ]
		then
			echo " > Your IP format is wrong. Octets can not be negative numbers. Please correct and try again. "
		fi			
	fi
done

while true; do
read -p " > Please enter slave node's IP: [Ex. 192.168.1.102] [Default=192.168.1.102]: " Input
	if [ -z $Input ]
	then
		Input="192.168.1.102"
	fi
	
	DotCount=`echo $Input | awk -F"." '{print NF-1}'`
	FirstOctet=`echo $Input | tr "." "\n" | head -1`
	SecondOctet=`echo $Input | tr "." "\n" | head -2 | tail -1`
	ThirdOctet=`echo $Input | tr "." "\n" | head -3 | tail -1`
	FourthOctet=`echo $Input | tr "." "\n" | head -4 | tail -1`
	if [ $DotCount -eq 3 ] && [ $FirstOctet -lt 255 ] && [ $SecondOctet -lt 255 ] && [ $ThirdOctet -lt 255 ] && [ $FourthOctet -lt 255 ] && [ $FirstOctet -gt 0 ] && [ $SecondOctet -ge 0 ] && [ $ThirdOctet -ge 0 ] && [ $FourthOctet -ne 0 ]
	then
		Slave_Node_IP=${Input}
		break
	else
		if [ $FourthOctet -ne 0 ]
		then
			echo " > Your IP format is wrong. Last octet can not be zero. Please correct and try again. "
		fi
		
		if [ $FirstOctet -eq 0 ]
		then
			echo " > Your IP format is wrong. First octet can not be zero. Please correct and try again. "
		fi
		
		if [ $FirstOctet -ge 255 ] || [ $SecondOctet -ge 255 ] || [ $ThirdOctet -ge 255 ] || [ $FourthOctet -ge 255 ]
		then
			echo " > Your IP format is wrong. Octets must be less than 255. Please correct and try again. "
		fi	
		
		if [ $FirstOctet -lt 0 ] || [ $SecondOctet -lt 0 ] || [ $ThirdOctet -lt 0 ] || [ $FourthOctet -lt 0 ]
		then
			echo " > Your IP format is wrong. Octets can not be negative numbers. Please correct and try again. "
		fi			
	fi
done

# check if the passwords match to prevent headaches
while true
do
	read -sp " > SSH connection to slave node will be tested. Please input root user's password:" Password1
	printf "\n"
	read -sp " > Please confirm root user's password:" Password2
	printf "\n"
	if [ \( "$Password1" != "$Password2" \) -o \( "$Password1" == "" -a "$Password2" == "" \) ]
	then
		echo " > Your passwords do not match; please try again..."
	else
		Slave_Node_Password=$Password1
		break
	fi
done

while true
do
	SSHPass_Control=`dpkg -l | grep sshpass | wc -l`
	if [ $SSHPass_Control -ne 1 ]
	then
		read -p " > 'sshpass' package not found. Please install it before continue. Do you want to continue? [y/n]" Answer
		case $Answer in
			[Yy]* )
					;;
			[Nn]* )	exit 1
					;;
			* )	echo " > Please answer [y]es or [n]o."
					;;
		esac	
	else
		SSHPass_Application_Full_Path=`which sshpass`
		SSH_Application_Full_Path=`which ssh`
		SSH_Control=`$SSHPass_Application_Full_Path -p $Slave_Node_Password $SSH_Application_Full_Path root@$Slave_Node_IP "/bin/uname"`
		if [ "$SSH_Control" == "Linux" ]
		then
			echo " > SSH connection succeeded."
			break
		else
			read -p " > SSH connection failed. Do you want to continue? [y/n]" Answer 
			case $Answer in
				[Yy]* )	break
						;;
				[Nn]* )	
						;;
				*)	echo " > Please answer [y]es or [n]o."
						;;
			esac
		fi
	fi
done

while true
do
	read -p " > Do you want to install MariaDB-Server on master and slave node(s)? [y/n]: " Answer
	case $Answer in
		[Yy]* )
				apt -y install mariadb-server
				Installed_On_Master=`dpkg -l | grep mariadb-server | wc -l`
				Service_Up_On_Master=`/bin/systemctl | grep mysql.service | grep 'active running' | wc -l`
				$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "apt -y install mariadb-server"
				Installed_On_Slave=`$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "dpkg -l | grep mariadb-server | wc -l"`
				Service_Up_On_Slave=`$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "/bin/systemctl | grep mysql.service | grep 'active running' | wc -l"`
				if [ $Installed_On_Master -ge 3 ] && [ $Installed_On_Slave -ge 3 ] && [ $Service_Up_On_Master -eq 1 ] && [ $Service_Up_On_Slave -eq 1 ] 
				then
					echo " > Installation completed successfully on both servers."
					break
				else
					if [ $Installed_On_Master -lt 3 ] || [ $Service_Up_On_Master -ne 1 ]
					then
						echo " > Installation of MariaDB-Server on master server failed."
					fi
					if [ $Installed_On_Slave -lt 3 ] || [ $Service_Up_On_Slave -ne 1 ]
					then
						echo " > Installation of MariaDB-Server on slave server failed."
					fi					
					read -p " > Do you want to continue? [y/n]" Answer 
					case $Answer in
						[Yy]* )	break
								;;
						[Nn]* )	
								;;
						*)	echo " > Please answer [y]es or [n]o."
								;;
					esac					
				fi
				;;
		[Nn]* )
				break
				;;
		*)	echo " > Please answer [y]es or [n]o."
				;;
	esac
done		

echo " > Mysql configuration will start in order to up&run 'Master - Slave Replication'"
CNF_File_Full_Path="/etc/mysql/my.cnf"
CNF_File=`echo $CNF_File_Full_Path | sed 's/\//\n/g' | tail -1`
CNF_File_Path=`echo $CNF_File_Full_Path | sed 's/\$CNF_File//g'`
CNF_Backup_File_Full_Path="/etc/mysql/my.cnf.before.replication"

if [ -e $CNF_File_Full_Path ]
then
	/bin/cp $CNF_File_Full_Path $CNF_Backup_File_Full_Path
else
	while true
	do
		read -p " > '$CNF_File_Full_Path' not found. Do you want to continue? [y/n]" Answer 
		case $Answer in
			[Yy]* )	break
					;;
			[Nn]* )	
					;;
			*)	echo " > Please answer [y]es or [n]o."
					;;
		esac
	done
fi

Control1=`cat $CNF_File_Full_Path | grep '\[mysqld]' | wc -l`
if [ $Control1 -ne 1 ]
then
	echo "[mysqld]" >> $CNF_File_Full_Path
	echo "#skip-networking" >> $CNF_File_Full_Path
	echo "#bind-address=127.0.0.1" >> $CNF_File_Full_Path
	echo "bind-address="$Master_Node_IP >> $CNF_File_Full_Path
	echo "log-bin=mysql-bin" >> $CNF_File_Full_Path
	echo "server-id=1" >> $CNF_File_Full_Path
	while true
	do
		read -p " > Please enter database name to be replicated. [ Enter 'q' after finish ] : " DB_Name
		if [ "$DB_Name" == "q" ]
		then
			echo "binlog-do-db=mysql" >> $CNF_File_Full_Path
			break
		else
			echo "binlog-do-db="$DB_Name >> $CNF_File_Full_Path
SQL_Output=`mysql <<EOF_SQL
SHOW DATABASES LIKE '$DB_Name';
exit
EOF_SQL`
SQL_DB_Count=`echo $SQL_Output | awk '{print $3}' | grep $DB_Name | wc -l`
			if [ $SQL_DB_Count -ne 1 ]
			then
				read -p " > Database "$DB_Name" not found. Please create it first. OK?" OK
			fi
		fi
	done
fi

/bin/systemctl restart mysql.service
Service_Up_On_Master=`/bin/systemctl | grep mysql.service | grep 'active running' | wc -l`

if [ $Service_Up_On_Master -ge 1 ]
then
	echo " > Mysql service restarted. Service status is 'active running'"
else
	while true
	do
		read -p "  > Mysql service status is not 'active running'. Do you want to continue? [y/n]: " Answer
		case $Answer in
			[Yy]* ) 
					break;;
			[Nn]* )
					;;
			* ) 	echo " please answer [y]es or [n]o.";;
		esac
	done
fi



while true
do
	read -sp " > A database user will be created for slave node connection. Please input a password for 'slave_user':" Password1
	printf "\n"
	read -sp " > Please confirm password for 'slave_user':" Password2
	printf "\n"
	if [ \( "$Password1" != "$Password2" \) -o \( "$Password1" == "" -a "$Password2" == "" \) ]
	then
		echo " > Your passwords do not match; please try again..."
	else
		Slave_DB_User_Pass=$Password1
		break
	fi
done

while true
do
	read -sp " > A database backup user will be created for slave node connection. Please input a password for 'backup_user':" Password1
	printf "\n"
	read -sp " > Please confirm password for 'backup_user':" Password2
	printf "\n"
	if [ \( "$Password1" != "$Password2" \) -o \( "$Password1" == "" -a "$Password2" == "" \) ]
	then
		echo " > Your passwords do not match; please try again..."
	else
		Backup_User_Pass=$Password1
		break
	fi
done

SQL_Output=`mysql <<EOF_SQL
GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY '$Slave_DB_User_Pass';
FLUSH PRIVILEGES;
CREATE USER 'backup_user'@'$Slave_Node_IP' IDENTIFIED BY '$Backup_User_Pass';
exit
EOF_SQL`

Database_To_Be_Replicated_Count=`cat $CNF_File_Full_Path | grep "binlog-do-db" | grep -v "mysql" | wc -l`
cat $CNF_File_Full_Path | grep "binlog-do-db" | grep -v "mysql" | cut -d'=' -f 2 >> /root/Database_To_Be_Replicated_List
Database_Names=`cat /root/Database_To_Be_Replicated_List | tr '\n' ' '`
cat /root/Database_To_Be_Replicated_List | while read line
do

SQL_Output=`mysql <<EOF_SQL			
GRANT SELECT, LOCK TABLES ON $line.* TO 'backup_user'@'$Slave_Node_IP';
exit
EOF_SQL`

done

		

SQL_Output=`mysql <<EOF_SQL			
GRANT SELECT, LOCK TABLES ON mysql.* TO 'backup_user'@'$Slave_Node_IP';
exit
EOF_SQL`

DB_Name1_To_Be_Replicated=`cat /root/Database_To_Be_Replicated_List | head -1`
rm -f /root/Database_To_Be_Replicated_List

SQL_Output=`mysql <<EOF_SQL		
USE $DB_Name1_To_Be_Replicated;
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
exit
EOF_SQL`

SQL_Binary_File_Name=`echo $SQL_Output | awk '{print $5}'`
SQL_Position=`echo $SQL_Output | awk '{print $6}'`

echo " > Database backup will be taken and injected to the database on slave server."
mysqldump --all-databases > /root/Backup.sql
$SSHPass_Application_Full_Path -p $Slave_Node_Password scp /root/Backup.sql root@$Slave_Node_IP:/root/Backup.sql
$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "mysql < /root/Backup.sql"

SQL_Output=`mysql <<EOF_SQL		
UNLOCK TABLES;
exit
EOF_SQL`			
			
$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "/bin/cp $CNF_File_Full_Path $CNF_Backup_File_Full_Path"

Control1=`$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "cat $CNF_File_Full_Path | grep '\[mysqld]' | wc -l"`
if [ $Control1 -ne 1 ]
then
	$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "echo '[mysqld]' >> $CNF_File_Full_Path"
	$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "echo '#skip-networking' >> $CNF_File_Full_Path"
	$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "echo '#bind-address=127.0.0.1' >> $CNF_File_Full_Path"
	$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "echo 'server-id=2' >> $CNF_File_Full_Path"
fi

$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "/bin/systemctl restart mysql.service"
Service_Up_On_Slave=`$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "/bin/systemctl | grep mysql.service | grep 'active running' | wc -l"`

if [ $Service_Up_On_Slave -ge 1 ]
then
	echo " > Mysql service restarted on slave. Service status is 'active running'"
else
	while true
	do
		read -p "  > Mysql service status is not 'active running' on slave. Do you want to continue? [y/n]: " Answer
		case $Answer in
			[Yy]* ) 
					break;;
			[Nn]* )
					;;
			* ) 	echo " please answer [y]es or [n]o.";;
		esac
	done
fi
# 
#$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "SQL_Output=`mysql <<EOF_SQL
#CHANGE MASTER TO MASTER_HOST='$Master_Node_IP', MASTER_USER='slave_user', MASTER_PASSWORD='$Slave_DB_User_Pass', MASTER_LOG_FILE='$SQL_Binary_File_Name', MASTER_LOG_POS=$SQL_Position;
#exit
#EOF_SQL`"
#
#
#$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "/bin/systemctl restart mysql.service"
#Service_Up_On_Slave=`$SSHPass_Application_Full_Path -p $Slave_Node_Password ssh root@$Slave_Node_IP "/bin/systemctl | grep mysql.service | grep 'active running' | wc -l"`
#
#if [ $Service_Up_On_Slave -ge 1 ]
#then
#	echo " > Mysql service restarted on slave. Service status is 'active running'"
#else
#	while true
#	do
#		read -p "  > Mysql service status is not 'active running' on slave. Do you want to continue? [y/n]: " Answer
#		case $Answer in
#			[Yy]* ) 
#					break;;
#			[Nn]* )
#					;;
#			* ) 	echo " please answer [y]es or [n]o.";;
#		esac
#	done
#fi
#
#
#/bin/systemctl restart mysql.service
#Service_Up_On_Master=`/bin/systemctl | grep mysql.service | grep 'active running' | wc -l`
#
#if [ $Service_Up_On_Master -ge 1 ]
#then
#	echo " > Mysql service restarted. Service status is 'active running'"
#else
#	while true
#	do
#		read -p "  > Mysql service status is not 'active running'. Do you want to continue? [y/n]: " Answer
#		case $Answer in
#			[Yy]* ) 
#					break;;
#			[Nn]* )
#					;;
#			* ) 	echo " please answer [y]es or [n]o.";;
#		esac
#	done
#fi

echo " > FINISHED..."
			