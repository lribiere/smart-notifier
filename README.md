# smart-notifier

Context : 
The smart-notifier project allows you to get email notifications when new articles comes out on a specific request (characterized by a url) on Leboncoin's website.

How to :

1- Replace in the toy_exemple.sh script the url and specify your email adress(es) (2 max.). Don't Forget to specify the correct absolute path to the launch script.

2- Add a new line in crontab (crontab -e) launching your script at the pace you want, here is an example :

*/5 * * * * /your/path/to/toy_exemple.sh >> /your/log/folder/toy_example.logs 2>&1

3- Enjoy :-)

Important note : 
Considering Leboncoin's recent website's update, I cannot ensure that the parsing of the page still works today...
