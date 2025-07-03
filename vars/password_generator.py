# Execute the following on an alpine virtual machine to generate the password

import crypt

print(crypt.crypt("123456", crypt.mksalt(crypt.METHOD_SHA512)))
