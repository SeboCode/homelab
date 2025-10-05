#!/bin/python
import os

from ansible.errors import AnsibleFilterError
from passlib.hash import pbkdf2_sha512


def mosquitto_pbkdf2_sha512(password, salt=None, rounds=101):
    """
    Generate a Mosquitto-compatible PBKDF2-SHA512 password hash.

    Args:
        password (str): The plaintext password.
        salt (str, optional): Hexadecimal salt. If None, a random 8-byte salt is generated.
        rounds (int, optional): Number of PBKDF2 iterations. Defaults to Mosquitto's default 101.

    Returns:
        str: Mosquitto-compatible PBKDF2-SHA512 hash, e.g. $7$ROUNDS$SALT$HASH
    """
    try:
        if salt is None:
            salt = os.urandom(12)

        digest = pbkdf2_sha512.using(salt=salt, rounds=rounds).hash(password)
        # Replace the password function identifier, as mosquitto expects 7 and passlib generates
        # pbkdf2-sha512. In addition, passlib uses a shortened base64 encoding. to make up for this,
        # we have to replace `.` with `+` and add `==` at the end.
        return digest.replace("pbkdf2-sha512", "7").replace(".", "+") + "=="
    except Exception as e:
        raise AnsibleFilterError("Error generating Mosquitto SHA512 hash") from e


class FilterModule(object):

    def filters(self):
        return {"mosquitto_password_hash": mosquitto_pbkdf2_sha512}
