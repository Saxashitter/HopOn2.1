import time
import subprocess
import os
import signal

from git import Repo

# VARIABLES
SRB2_PATH = "SRB2/bin/lsdl2srb2"
MODS_PATH = ".srb2/repos/HopOn2.1"

restarting = False

def git_pull_change(path):
    repo = Repo(path)
    current = repo.head.commit

    repo.remotes.origin.pull()

    if current == repo.head.commit:
        return False
    else:
        return True

def run_make(target=None, makefile_path=None):
    command = ["make"]
    if target:
        command.append(target)

    try:
        process = subprocess.Popen(
            command,
            cwd=makefile_path,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        stdout, stderr = process.communicate()
        return_code = process.returncode
        return return_code, stdout, stderr
    
    except FileNotFoundError:
        return -1, "", "Error: make command not found. Is it installed?"
    
    except Exception as e:
         return -1, "", f"An unexpected error occurred: {e}"

print("HOP ON 2.1 SERVER RUNNER - BY SAXASHITTER")

def update(force_make=False):
    global srb2

    if not force_make:
        print("Checking for updates...")

    if git_pull_change("/root/"+MODS_PATH):
        print("Update found! Making build...")
        run_make(None, "/root/"+MODS_PATH)
        print("Finished!")
    elif force_make:
        print("Making build...")
        run_make(None, "/root/"+MODS_PATH)
        print("Finished!")
    else:
        print("No updates. Finished!")

    print("Running SRB2...")
    srb2 = subprocess.Popen(["/root/"+SRB2_PATH+" -dedicated -room 33"], shell=True)

update()

while True:
    running = srb2.poll() is None

    if running and not restarting and git_pull_change("/root/"+MODS_PATH):
        print("Update detected, restarting!")
        f = open("/root/.srb2/luafiles/client/servercomms.txt", "w")
        f.write("quit")
        f.close()
        restarting = True
        continue

    if not running:
        update(restarting)
        restarting = False
        time.sleep(1)

    time.sleep(10)
