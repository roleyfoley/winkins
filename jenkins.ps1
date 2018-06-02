Write-Output "Starting Jenkins..."

$JENKINS_WAR='C:/Program Files/Jenkins/jenkins.war'

Start-Process -Wait -FilePath java -ArgumentList @( "-Duser.home=`"$ENV:JENKINS_HOME`"", '-jar', "`"$JENKINS_WAR`"" )