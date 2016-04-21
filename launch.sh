#!/bin/bash
#set -x
set -e 

function helptext {
	echo "Usage : <Url> <Email address - To> [Email address - Cc]"
}

function sendMail {
	subject=$1
	body=$(echo "$2" | sed 's/;/\n/g')
	to=$3
	cc=$4
	resultUrl=$5

	intro="Hello,\n\n"
	paraph="\n\nReminder - this is the result page of your request : $resultUrl \n\nThank you for using our service.\nThe Instant Notifier's team"
	toSend="From: Instant Notifier <no-reply@instantnotifier.com>\nTo: ${to}\nCc: ${cc}\nSubject: ${subject}\n\n${intro}${body}${paraph}"

	echo -e "##########  EMAIL BEGINNING  ##########"
	echo -e "${toSend}"
	echo -e "##########  EMAIL END  ##########"
	echo -e "$toSend" | sendmail -t
}

function sendFiveMostRecent {
	subject=$1
	url=$2
	emailTo=$3
	emailCc=$4
#	echo -e "##########Test########## - subject : $subject"
#	echo -e "##########Test########## - url : $url"
#	echo -e "##########Test########## - emailTo : $emailTo"
#	echo -e "##########Test########## - emailCC : $emailCc"

	echo -e "Sending the five most recent articles to email adresses specified in arguments"
	head -1 workingFolder/page1.idsUrls | cut -f1 > workingFolder/lastId
	body="Here are the links of the 5 most recent articles on your request :\n\n$(head -5 workingFolder/page1.idsUrls | cut -f 2)"
	sendMail "$subject" "$body" "$emailTo" "$emailCc" "$url"
}

function replaceId {
	oldId=$1
	newId=$2
	if [ -z "$newId" ]; then
		echo "Aborting id replacement : new id is empty !"
		return 1
	else
		echo -e "Replacing last Id (${oldId}) with new one : $newId"
		echo $newId > workingFolder/lastId
		echo "Id replacement : done !"
	fi
}

if [[ $# -lt 2 ]]
then
	helptext
	exit 1
fi

url=$1
emailTo=$2
emailCc=$3

echo "--------------------------------"
echo -e "Launching retrieval for : "
echo -e "\t- url\t\t: $url"
echo -e "\t- emailTo\t: ${emailTo}"
echo -e "\t- emailCc\t: ${emailCc}"

receiverFile="$(date +%F_%H:%M:%S)_lbc"
echo -e "Receiver file : ${receiverFile}"

if [ ! -d "workingFolder" ]; then
	mkdir workingFolder
fi

wget -q -O "workingFolder/$receiverFile" "$url"
if [ ! -f "workingFolder/$receiverFile" ]; then
	echo -e "Wget command failed to download the web content. Exiting script."
	exit 1
fi

cleanFile="workingFolder/${receiverFile}.cleaned"

cat workingFolder/$receiverFile | sed '/^[[:space:]]*$/d' | sed -e 's/^[ \t]*//' > $cleanFile
rm -f workingFolder/$receiverFile

# This is ugly, I gotta find a better way to get all the articles...
begin=$(grep -n 'class="list-lbc"' ${cleanFile} | cut -d: -f1)
endAlerte=$(grep -n 'id="alertesCartouche"' ${cleanFile} | cut -d: -f1)
endAfs=$(grep -n 'id="afs-main"' ${cleanFile} | cut -d: -f1)

if [ -z "$begin" -o \( -z "$endAlerte" -a -z "$endAfs" \) ]; then
	echo -e "Failed to parse web page correctly. Exiting !"
	exit 1
fi

if [ -n "$endAlerte" ]; then end="$endAlerte"; else end="$endAfs"; fi

lineNumb=$((${end} - ${begin}))

#cat $cleanFile | tail -n +${begin} | head -n ${lineNumb} | grep '<a href="http://www.leboncoin.fr' | grep "title" | cut -d" " -f2 | cut -d= -f2 | sed 's/"//' | cut -d? -f1 > workingFolder/page1.urls
cat $cleanFile | tail -n +${begin} | head -n ${lineNumb} | grep '<a href="' | grep "title" | cut -d"?" -f1 | cut -d"/" -f3,4,5 > workingFolder/page1.urls
#cat $cleanFile | tail -n +${begin} | head -n ${lineNumb} | grep '<a href="http://www.leboncoin.fr' | grep "title" | cut -d. -f3 | cut -d/ -f3 > workingFolder/page1.ids
cat $cleanFile | tail -n +${begin} | head -n ${lineNumb} | grep '<a href="' | grep "title" | cut -d"?" -f1 | cut -d"/" -f5 | cut -d"." -f1 > workingFolder/page1.ids

paste workingFolder/page1.ids workingFolder/page1.urls > workingFolder/page1.idsUrls
rm -f workingFolder/page1.ids workingFolder/page1.urls $cleanFile
newId=$(head -1 workingFolder/page1.idsUrls | cut -f1)
echo -e "New id : $newId"


if [ -s "workingFolder/lastId" ]; then
	#lastId file exists and have a size greater than 0
	oldId=$(cat workingFolder/lastId)
	echo -e "Old id exists and is equal to : ${oldId}"
	nbOfArticlesLackingPlusOne=$(grep -n -w $oldId workingFolder/page1.idsUrls | cut -d: -f1)
	if [ -z $nbOfArticlesLackingPlusOne ]; then
		#Difficult case : last id wasn't found (in page 1)
		# nbOfArticlesLackingPlusOne variable is empty because grep on couple of lines earlier did not yield anything.
		echo "Difficult case : previously known article id could not be found (whether it's after page 1 or article does not exist anymore"
		replaceId $oldId $newId
		subject="Previous known id not found in result page - Sending five most recent articles"
		sendFiveMostRecent "$subject" "$url" "$emailTo" "$emailCc"
	elif [ $nbOfArticlesLackingPlusOne -gt 1 ]; then
		#New article(s) need to be sent
		nbOfArticlesLacking=$(( $nbOfArticlesLackingPlusOne - 1 ))
		echo -e "Number of lacking articles : $nbOfArticlesLacking"
		replaceId $oldId $newId
		subject="$nbOfArticlesLacking new article(s) for your request"
		body="Here is(are) the link(s) of the new article(s) that came out for your request : \n$(head -n $nbOfArticlesLacking workingFolder/page1.idsUrls | cut -f 2 | sed 's/ /;/g')"
		sendMail "$subject" "$body" "$emailTo" "$emailCc" "$url"
	else
		#No new article to send
		echo -e "Nothing new to send !"
	fi
else
	if [ -f "workingFolder/lastId" ]; then
		#lastId file exits but is empty. Reporting error and sending the 5 most recent articles.
		echo -e "Old id was lost ! Sending 5 most recent articles and placing new id."
		replaceId "lost" $newId
		subject="Last Id was lost - Sending five most recent articles for your request"
	else
		#lastId file does not exists. This should be the first query, sending the 5 most recent articles in consequence.
		echo -e "First query ! Sending 5 most recent articles and creating last Id file."
		head -1 workingFolder/page1.idsUrls | cut -f1 > workingFolder/lastId
		subject="First Request - Five most recent articles for your request"
	fi
	sendFiveMostRecent "$subject" "$url" "$emailTo" "$emailCc"
fi

rm workingFolder/page*.idsUrls

echo "Done !"
