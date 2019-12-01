#!/bin/bash
#    ____             ____   ____
#   / ___|_ __  _   _|  _ \ / ___|
#  | |  _| '_ \| | | | |_) | |  _
#  | |_| | | | | |_| |  __/| |_| |
#   \____|_| |_|\__,_|_|    \____| Messages Manager
#
# Interactive application for encrypting
# and decrypting PGP messages efficiently.
# Dependencies : GnuPG, FZF

#Defining home directory variable and default text editor

gpgDir=$HOME/Documents/pgp
editor=vim

# Text format 

bs=$(tput bold)
be=$(tput sgr0)

# Text color

red='\033[0;31m'
green='\033[0;32m'
end='\033[0m'

#The function checkDependencies() allows us to verify if the user has installed the required software in order to use this script 

function checkDependencies() {
		dependencies=( gpg fzf $editor )
		ready=0

		for i in "${dependencies[@]}"; do
				which $i > /dev/null

				if [ $? -ne 0 ]; then
						ready=1
						break
				fi
		done

		if [ $ready -eq 0 ]; then
				checkDirectories
		else
				exit 1
		fi
}

#The function checkDirectories() allows us to verify if the directories we need already exists or if we needto create them

function checkDirectories() {
 	cd $HOME

 	if [ ! -d Documents ]; then
 		mkdir -p Documents/pgp/{asc,pub,txt}

 	elif [ ! -d Documents/pgp ]; then
 		mkdir -p Documents/pgp/{asc,pub,txt}

 	elif [ ! -d Documents/pgp/asc ]; then
 			mkdir Documents/pgp/asc

 	elif [ ! -d Documents/pgp/pub ]; then
 			mkdir Documents/pgp/pub

 	elif [ ! -d Documents/pgp/txt ]; then
 			mkdir Documents/pgp/txt

 	else
 		echo "All OK."
 	fi

	checkAddr
}

#The function showKeys() allows us to show every public keys the user has added to his keyring

function showKeys() {
	echo
	gpg --list-keys |
		grep -E '^uid' |
		sed 's/^.\+\] //' |
		sed 's/>//' |
		sed 's/ </;/' |
		cut -d ';' -f 1- --output-delimiter=$'\t\t\t'

	if [ "$1" == "i" ]; then
		toMenu
	fi
}

#The function toMenu() is not a function that the user is going to see it's just use at the end of almost every other function in order to go back to the menu once the user has finished using a functionality

function toMenu() {
	echo; read -p "Press Enter to continue..." foo
	showMenu
}

#The function selectKey() is not a function that the user is going to see it's just the way that the user isgoing to select a public key

function selectKey() {
	showKeys | fzf | cut -f4 -d $'\t'
}

#The function checkAddr() is not a function that the user is going to see it  allows us to verify if the file we need already exist if it doesn't exist we create it 

function checkAddr() {
	cd $gpgDir
	if [ -f txt/adr.txt ]; then
		if [ $(du txt/adr.txt) -le 0 ]; then
			setAddr
		else
			showMenu
		fi
	else
		setAddr
	fi
}


#The function setAddr() follow the checkAddr() function, once the file is created we ask the user to writehis adress in adr.txt

function setAddr() {
	echo -e "You firstly need to specify your address."
	read -p "Press Enter to enter your address..." foo
	vim $gpgDir/txt/adr.txt
	checkAddr
}

#The function showMenu() allows us to bring to the user a simple presentation to all functionalities

function showMenu() {
	clear
	echo "${bs}Welcome to GnuPG !${be}"; echo
	echo "
[1] Show keyring
[2] Generate a new public key
[3] Import a public key
[4] Remove a public key
[5] Encrypt your address
[6] Encrypt a message
[7] Decrypt a message

[0] Exit
"
	askOption
}

#The function encryptMsg() use the gpg functionality to encrypt a message from the user input

function encryptMsg() {
	showKeys
	cd $gpgDir
	echo; read -p "Press Enter to select a recipient..." foo
	recipient=$(selectKey)

	if [ "$1" == "adr" ]; then
		gpg --trust-model always --armor --encrypt --recipient $recipient txt/adr.txt

		if [ $? -eq 0 ]; then
			recipientFormat=$(echo -n 'adr_for_'; echo $recipient | sed 's/@.\+$//')
			mv txt/adr.txt.asc asc/$recipientFormat.asc
			echo -e "\n${green}Address encrypted for ${bs}${recipient}${be}\nto $gpgDir/asc/${bs}$recipientFormat.asc${be} !${end}\n"
		else
			echo -e "\n${red}Warning: An error occured. Please refer to gpg.log.${end}"
		fi

	else
		echo; read -p "Press Enter to start writing your message..." foo
		vim txt/tmp.txt
		gpg --trust-model always --armor --encrypt --recipient $recipient txt/tmp.txt

		if [ $? -eq 0 ]; then
			recipientFormat=$(echo -n 'msg_for_'; echo -n $recipient | sed 's/@.\+$/_/'; date +%Y%m%d_%H%M%S)
			mv txt/tmp.txt.asc asc/$recipientFormat.asc
			rm txt/tmp.txt
			echo -e "\n${green}Message encrypted for ${bs}${recipient}${be}\nto $gpgDir/asc/${bs}$recipientFormat.asc${be} !${end}"
		else
			echo -e "\n${red}Warning: An error occured. Please refer to gpg.log.${end}"
		fi
	fi

	toMenu
}

#The function addPubKey() allows the user to add a public key to his keyring if he register a public key 

function addPubKey() {
	cd $gpgDir
	echo; ls pub/ | head -n99
	echo; read -p "Press Enter to select a public key..."
	public=$(ls pub/ | head | fzf)
	gpg --batch --yes --import pub/$public

	if [ $? -eq 0 ]; then
		echo -e "${green}\nPublic key $public added !${end}"
		toMenu
	else
		echo -e "\n${red}Warning: An error occured. Please refer to gpg.log.${end}"
	fi
}

#The function delPublicKey() allows the user to delete a public key from his keyring

function delPubKey() {
	echo; showKeys
	echo; read -p "Press Enter to select a public key..."
	public=$(selectKey)
	gpg --batch --yes --delete-key $public

	if [ $? -eq 0 ]; then
		echo -e "${green}Public key $public deleted !${end}"
		toMenu
	else
		echo -e "\n${red}Warning: An error occured. Please refer to gpg.log.${end}"
	fi
}

#The function genKey() allows the user to generate a key pair (the private key and the public key)

function genKey() {
	gpgVersion=$(gpg --version | sed 1q | cut -d ' ' -f3)
	if [ $(echo -e "2.2.17\n${gpgVersion}" | sort -V | head -n1) == "2.2.17" ]; then
		# GPG version is greather than 2.2.17
		gpg --full-generate-key
	else
		# GPG version is lower than 2.2.17
		gpg --gen-key
	fi

	toMenu
}

#The function decryptMsg() allows the user to decrypt a message from an external source thank to the public key of this external user

function decryptMsg() {
	cd $gpgDir
	messages=$(ls asc/ | grep '^msg' | head)
	echo -e "\n${messages}\n"
	read -p "Press Enter to select a message..." foo
	toDecryptMsg=$(echo -e "$messages" | fzf)
	gpg --output txt/$toDecryptMsg.txt --decrypt asc/$toDecryptMsg

	if [ $? -eq 0 ]; then
		echo RELOADAGENT | gpg-connect-agent
		echo -e "\n${green}Message successfully decrypted to $gpgDir/txt/${bs}$toDecryptMsg.txt${be} !${end}"
		echo -e "\nWould you like to see the message now ?\n[Y]es / [N]o\n"
		read -p ">>> " answerMsg

		while [[ ! $answerMsg == "Y" && ! $answerMsg == "y" && ! $answerMsg == "N" && ! $answerMsg == "n" ]]; do
			echo -e "\nPlease choose between Y or N !"
			read -p ">>> " answerMsg
		done

		if [[ $answerMsg == "Y" || $answerMsg == "y" ]]; then
			$editor txt/$toDecryptMsg.txt
		fi
	else
		echo -e "\n${red}Warning: An error occured. Please refer to gpg.log.${end}"
	fi

	toMenu
}

#The function askOption() allows to treat the user input in order to select wich funtion to call regardingthe user selection

function askOption() {

	echo; read -p ">>> " choice

	if [ ! -z $choice ]; then
		if [ $choice -eq $choice 2>/dev/null ]; then
			while [[ $choice -lt 0 || $choice -gt 7 ]]; do
				echo -e "\nPlease choose between 1 - 7 !"
				read -p ">>> " choice
			done
		fi
	else
		showMenu
	fi

	case $choice in
		0)
			exit;;
		1)
			showKeys "i";;
		2)
			genKey;;
		3)
			addPubKey;;
		4)
			delPubKey;;
		5)
			encryptMsg "adr";;
		6)
			encryptMsg;;
		7)
			decryptMsg;;
	esac
}

checkDependencies
