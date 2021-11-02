import sys
import csv

# Read in the input CSV
def parseFile():
    input=sys.argv[1]
    csv_file = open(input)
    read_tsv = csv.DictReader(csv_file)
    users=[]
    for row in read_tsv:
        users.append(row)
    return users

# Pull out the users from the input CSV file
users = parseFile()

# Reference to the temp SQL file created by parent bash script
sqlFile = open(sys.argv[2], 'a')

# For each user add a new line SQL statement to the temp SQL file
# Each line replaced the username with OID and clears the qualifications field
for user in users:
    oeID = user["id"]
    aadID = user["oid"]
    if not aadID:
        print(f"WARNING: User with id {oeID} does not have OID")
        continue
    nextLine=f"UPDATE user SET username='{aadID}', qualifications = '' WHERE id = '{oeID}';\n"
    sqlFile.write(nextLine)

sqlFile.close()