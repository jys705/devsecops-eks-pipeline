from flask import Blueprint, request
import subprocess

diag = Blueprint("diag", __name__)


@diag.route("/ping")
def ping():
    host = request.args.get("host", "")
    result = subprocess.run("ping -c 1 " + host, shell=True, capture_output=True)
    return result.stdout