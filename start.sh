#!/bin/bash
SESSION_NAME="pServe"
date=$(date '+%Y-%m-%d__%H%M')
logfile="/Projects/pServe/logs/log_$date.txt"
exec > >(tee ${logfile}) 2>&1
echo "$date :: BEGIN JOB."

projectpath="/Projects/pServe/http_serve.py"
projectpathdir="/Projects/pServe"
python_executable="/Projects/pServe/vfx/bin/python"
python_Venv="/Projects/pServe/vfx"
bash_executable="/bin/bash"

# Start a detached screen session, cd to the project directory, activate venv, then run the script
screen -dmSS $SESSION_NAME $bash_executable -c "cd $projectpathdir && source $python_Venv/bin/activate && python $projectpath"

echo "$date :: END JOB."
echo "$date :: Server started in screen session: $SESSION_NAME"
echo "$date :: Use 'screen -r $SESSION_NAME' to attach."
