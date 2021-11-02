import sys
import csv

# Take the TSV file and parse out the list into a list of users (dict)
def parseFile():
    input=sys.argv[2]
    tsv_file = open(input)
    read_tsv = csv.DictReader(tsv_file, delimiter="\t") # By default takes first line of the file as the keys for the dict
    users=[]
    for row in read_tsv:
        user = row
        user["oid"] = "" #We want a column to enter the OID to be filled
        users.append(user)

    return users

# Takes a list of users (dict) and filename and exports them into CSV
def toCSV(data, filename):
    board = sys.argv[1]
    keys = []
    if (len(data) > 0):
        # If there exists users, then the header line of the CSV is keys of the dict
        keys = data[0].keys() 
    with open(f'{filename}-{board}.csv', 'w', newline='') as output_file:
        dict_writer = csv.DictWriter(output_file, keys)
        dict_writer.writeheader()
        dict_writer.writerows(data)


users = parseFile()
accepted = []
rejected = []

# For each user, either add them to the accepted or rejected list
for user in users:
    current = user
    # Email is required field but it may not have always been, so covering for this case
    # We immediately add it to the rejected list and move on
    if not current["email"]:
        current["reason"] = "Missing email"
        rejected.append(current)
        continue

    # Check to see if a user with the current email list already exists in the accepted or rejected list
    acceptIndex = next((index for (index, accept) in enumerate(accepted) if accept["email"] == current["email"]), -1)
    rejectIndex = next((index for (index, reject) in enumerate(rejected) if reject["email"] == current["email"]), -1)

    # If email already exists in the accepted list add to rejected, and also remove from accepted
    if acceptIndex >= 0:
        reject = accepted[acceptIndex]
        reject["reason"] = "Duplicate Email"
        current["reason"] = "Duplicate Email"
        rejected.append(reject)
        rejected.append(current)
        accepted.pop(acceptIndex)
    # Case where 3 users have same email
    elif rejectIndex >= 0:
        current["reason"] = "Duplicate Email"
        rejected.insert(rejectIndex, current)
    # Else we are good to accept
    else:
        accepted.append(current)

# Export the accepted and rejected lists to a CSV for board consumption
toCSV(accepted, "accepted")
toCSV(rejected, "rejected")