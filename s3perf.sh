#!/bin/bash

#https://docs.minio.io/docs/minio-disk-cache-guide

#https://unix.stackexchange.com/questions/22387/how-do-0-and-0-work
#${0##*/} translates as: for the variable $0, and the pattern '/', the two hashes mean from the beginning of the parameter, delete the longest (or greedy) match—up to and including the pattern. 
#So, where $0 is the name of a file, eg., $HOME/documents/doc.txt, then the parameter would be expanded as: doc.txt
SCRIPT=${0##*/}   # script name
NUM_FILES=5
SIZE_FILES=1000000 
BUCKETNAME_PARAMETER=nick
UPPERCASE=0
SWIFT_API=0
MINIO_CLIENT=1
MINIO_CLIENT_ALIAS=ibm
AZURE_CLI=0
GOOGLE_API=0
NOT_CLEAN_UP=0
PARALLEL=0
LIST_OF_FILES=
OUTPUT_FILE=0
ENDPOINT_URL="--endpoint-url http://169.63.88.188:9001"
#ENDPOINT_URL=""

#http://jafrog.com/2013/11/23/colors-in-terminal.html
#ex:${GREEN} 
#\033 - ASCII octal Escape code
#[0;32 - Green color code
#m- finishing term
RED='\033[0;31m'          # Red color
NC='\033[0m'              # No color
GREEN='\033[0;32m'        # Green color
YELLOW='\033[0;33m'       # Yellow color
BLUE='\033[0;34m'         # Blue color
WHITE='\033[0;37m'        # White color

#https://linuxconfig.org/how-to-use-getopts-to-parse-a-script-options
#getopts commands must be used inside a while loop so all options are parsed. Then immediately after the getopts keyword, we defined the possible options our script will accept
#The colon tells getopts that the option requires an argument. Each parsed option will be stored inside the $OPTION variable, while an argument, when present, will become the value of the$OPTARG one
while getopts "hn:s:b:uamzgkpo" Arg ; do
  case $Arg in
    h) usage ;;
    n) NUM_FILES=$OPTARG ;;
    s) SIZE_FILES=$OPTARG ;;
    # If the flag has been set => $NOT_CLEAN_UP gets value 1
    b) BUCKETNAME_PARAMETER=1
       BUCKET=$OPTARG ;; 
    u) UPPERCASE=1 ;;
    a) SWIFT_API=1 ;;
    m) MINIO_CLIENT=1 
       MINIO_CLIENT_ALIAS=$OPTARG ;;
    z) AZURE_CLI=1 ;;
    g) GOOGLE_API=1 ;;
    k) NOT_CLEAN_UP=1 ;;
    p) PARALLEL=1 ;;
    o) OUTPUT_FILE=1 ;;
    \?) echo "Invalid option: $OPTARG" >&2
       exit 1
       ;;
  esac
done

# Path of the directory for the files
DIRECTORY="testfiles"

# Filename of the output file
OUTPUT_FILENAME=results.csv


# If the user did not want to specify the bucket name with the parameter -b <bucket>, ossperf will use the default bucket name
if [ "$BUCKETNAME_PARAMETER" -eq 0 ] ; then
  if [ "$UPPERCASE" -eq 1 ] ; then
    # Default bucket name in case the parameter -u was set => $UPPERCASE has value 1
    BUCKET="OSSPERF-TESTBUCKET"
  else
    # Default bucket name in case the parameter -u was not set => $UPPERCASE has value 0
    BUCKET="ossperf-testbucket"
  fi
fi


if aws $ENDPOINT_URL s3 rb s3://$BUCKET --force ; then
  echo -e "${GREEN}[OK] Bucket ${BUCKET} has been removed.${NC}"
fi
if rm -r testfiles ; then
  echo -e "${GREEN}[OK] Folder ${DIRECTORY} has been removed.${NC}"  
fi

# Validate that...
# NUM_FILES is not 0 
if [ "$NUM_FILES" -eq 0 ] ; then
  echo -e "${RED}Attention: The number of files must not be value zero!${NC}"
  usage
  exit 1
fi

# Validate that...
# SIZE_FILES is not 0 and not bigger than 16777216
if ( [[ "$SIZE_FILES" -eq 0 ]] || [[ "$SIZE_FILES" -gt 16777216 ]] ) ; then
   echo -e "${RED}Attention: The size of the file(s) must not 0 and the maximum size is 16.777.216 Byte!${NC}"
   usage
   exit 1
fi
 
 
# We shall check at least 5 times
LOOP_VARIABLE=5  
#until LOOP_VARIABLE is greater than 0 
while [ $LOOP_VARIABLE -gt "0" ]; do 
  # Check if we have a working network connection by sending a ping to 8.8.8.8
  if ping -q -c 1 -W 1 8.8.8.8 >/dev/null ; then
    echo -e "${GREEN}[OK] This computer has a working internet connection.${NC}"
    # Skip entire rest of loop.
    break
  else
    echo -e "${YELLOW}[INFO] The internet connection is not working now. Will check again.${NC}"
    # Decrement variable
    LOOP_VARIABLE=$((LOOP_VARIABLE-1))
    if [ "LOOP_VARIABLE" -eq 0 ] ; then
      echo -e "${RED}[ERROR] This computer has no working internet connection. Please check your network settings.${NC}" && exit 1
    fi
    # Wait a moment. 
    sleep 1
  fi
done

# Check if the directory already exists
# This is not a part of the benchmark!
if [ -e ${DIRECTORY} ] ; then
  # Terminate the script, in case the directory already exists
  echo -e "${RED}[ERROR] The directory ${DIRECTORY} already exists in the local directory!${NC}" && exit 1
else
  if mkdir ${DIRECTORY} ; then
    # Create the directory if it does not already exist
    echo -e "${GREEN}[OK] The directory ${DIRECTORY} has been created in the local directory.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the directory ${DIRECTORY} in the local directory.${NC}" && exit 1
  fi
fi

# Create files with random content of given size
# This is not a part of the benchmark!
for ((i=1; i<=${NUM_FILES}; i+=1))
do
  if dd if=/dev/urandom of=$DIRECTORY/ossperf-testfile$i.txt bs=1 count=$SIZE_FILES ; then
    echo -e "${GREEN}[OK] File with random content has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the file.${NC}" && exit 1
  fi
done

# Calculate the checksums of the files
# This is not a part of the benchmark!
#if md5sum $DIRECTORY/* > $DIRECTORY/MD5SUM ; then
#  echo -e "${GREEN}[OK] Checksums have been calculated and MD5SUM file has been created.${NC}"
#else
#  echo -e "${RED}[ERROR] Unable to calculate the checksums and create the MD5SUM file.${NC}" && exit 1
#fi

# Start of the 1st time measurement
#+%s.%N returns the seconds and current nanoseconds.
TIME_CREATE_BUCKET_START=`date +%s.%N`

# -------------------------------
# | Create a bucket / container |
# -------------------------------

# use the S3 API with s3cmd
if aws $ENDPOINT_URL s3 mb s3://$BUCKET ; then
  echo -e "${GREEN}[OK] Bucket ${BUCKET} has been created.${NC}"
else
  echo -e "${RED}[ERROR] Unable to create the bucket ${BUCKET}.${NC}" && exit 1
fi

# End of the 1st time measurement
TIME_CREATE_BUCKET_END=`date +%s.%N`

echo -e "TIME_CREATE_BUCKET_START is ${TIME_CREATE_BUCKET_START} TIME_CREATE_BUCKET_END is ${TIME_CREATE_BUCKET_END}"

TIME_CREATE_BUCKET=`echo "scale=3 ; (${TIME_CREATE_BUCKET_END} - ${TIME_CREATE_BUCKET_START})/1" | bc | sed 's/^\./0./'`

# Wait a moment. Sometimes, the services cannot provide fresh created buckets this quick
sleep 1

# We shall check at least 5 times
LOOP_VARIABLE=5
# until LOOP_VARIABLE is greater than 0 
while [ $LOOP_VARIABLE -gt "0" ]; do 
  # Check if the Bucket is accessible
  if aws $ENDPOINT_URL s3 ls s3://$BUCKET  ; then
     echo -e "${GREEN}[OK] The bucket is available.${NC}"
     # Skip entire rest of loop.
     break
   else
     echo -e "${YELLOW}[INFO] The bucket is not yet available!${NC}"
     # Decrement variable
     LOOP_VARIABLE=$((LOOP_VARIABLE-1))
     # Wait a moment. 
     sleep 1
   fi
done

# Start of the 2nd time measurement
TIME_OBJECTS_UPLOAD_START=`date +%s.%N`


# ------------------------------
# | Upload the Files (Objects) |
# ------------------------------

# If the "parallel" flag has been set, upload in parallel with GNU parallel
if [ "$PARALLEL" -eq 1 ] ; then
	echo -e "${GREEN}[OK] Uploading in parallel.${NC}"

else
# If the "parallel" flag has NOT been set, upload the files sequentially
	echo -e "${GREEN}[OK] Uploading in serial.${NC}"

	if aws $ENDPOINT_URL s3 sync $DIRECTORY s3://$BUCKET ; then
		echo -e "${GREEN}[OK] The objects has been uploaded using sync.${NC}"
     # Skip entire rest of loop.
     	break
    else
     echo -e "${YELLOW}[INFO] The bucket could not sync!${NC}"

    fi
fi
# End of the 2nd time measurement
TIME_OBJECTS_UPLOAD_END=`date +%s.%N`

# Duration of the 2nd time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_OBJECTS_UPLOAD=`echo "scale=3 ; (${TIME_OBJECTS_UPLOAD_END} - ${TIME_OBJECTS_UPLOAD_START})/1" | bc | sed 's/^\./0./'`


# Calculate the bandwidth
# ((Size of the objects * number of objects * 8 bits per byte) / TIME_OBJECTS_UPLOAD) and next
# convert to Megabit per second
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
BANDWIDTH_OBJECTS_UPLOAD=`echo "scale=3 ; ((((${SIZE_FILES} * ${NUM_FILES} * 8) / ${TIME_OBJECTS_UPLOAD}) / 1000) / 1000) / 1" | bc | sed 's/^\./0./'`

# Wait a moment. Sometimes, the services cannot provide fresh uploaded files this quick
sleep 1

# Start of the 3rd time measurement
TIME_OBJECTS_LIST_START=`date +%s.%N`

# ----------------------------------------
# | List files inside bucket / container |
# ----------------------------------------
# In the Swift and Azure ecosystem, the buckets are called conainers. 

# use the S3 API with s3cmd
if aws $ENDPOINT_URL s3 ls s3://$BUCKET  ; then
   echo -e "${GREEN}[OK] The list of objects inside ${BUCKET} has been fetched.${NC}"
else
   echo -e "${RED}[ERROR] Unable to fetch the list of objects inside ${BUCKET}.${NC}" && exit 1
fi

# End of the 3rd time measurement
TIME_OBJECTS_LIST_END=`date +%s.%N`

# Duration of the 3rd time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_OBJECTS_LIST=`echo "scale=3 ; (${TIME_OBJECTS_LIST_END} - ${TIME_OBJECTS_LIST_START})/1" | bc | sed 's/^\./0./'`

# Start of the 4th time measurement
TIME_OBJECTS_DOWNLOAD_START=`date +%s.%N`
echo -e "${GREEN}[OK] TIME_OBJECTS_DOWNLOAD_START ${TIME_OBJECTS_DOWNLOAD_START}.${NC}"
# --------------------------------
# | Download the Files (Objects) |
# --------------------------------
# If the "parallel" flag has been set, upload in parallel with GNU parallel
if [ "$PARALLEL" -eq 1 ] ; then
	echo -e "${GREEN}[OK] Downloading in parallel.${NC}"

else
# If the "parallel" flag has NOT been set, upload the files sequentially
	echo -e "${GREEN}[OK] Downloading in serial.${NC}"

	if aws $ENDPOINT_URL s3 cp  s3://$BUCKET $DIRECTORY --force --recursive; then
		echo -e "${GREEN}[OK] The objects has been downloaded.${NC}"
     # Skip entire rest of loop.
     	break
    else
     echo -e "${YELLOW}[INFO] The bucket could not sync!${NC}"

    fi
fi

# End of the 4th time measurement
TIME_OBJECTS_DOWNLOAD_END=`date +%s.%N`
echo -e "${GREEN}[OK] TIME_OBJECTS_DOWNLOAD_END ${TIME_OBJECTS_DOWNLOAD_END}.${NC}"

# Duration of the 4th time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_OBJECTS_DOWNLOAD=`echo "scale=3 ; (${TIME_OBJECTS_DOWNLOAD_END} - ${TIME_OBJECTS_DOWNLOAD_START})/1" | bc | sed 's/^\./0./'`
echo -e "${GREEN}[OK] TIME_OBJECTS_DOWNLOAD ${TIME_OBJECTS_DOWNLOAD}.${NC}"

# Validate the checksums of the files
# This is not a part of the benchmark!
#if md5sum -c $DIRECTORY/MD5SUM ; then
#  echo -e "${GREEN}[OK] Checksums have been validated and match the files.${NC}"
#else
#  echo -e "${RED}[ERROR] The checksums do not match the files.${NC}" && exit 1
#fi


# Calculate the bandwidth
# ((Size of the objects * number of objects * 8 bits per byte) / TIME_OBJECTS_DOWNLOAD) and next
# convert to Megabit per second
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
BANDWIDTH_OBJECTS_DOWNLOAD=`echo "scale=3 ; ((((${SIZE_FILES} * ${NUM_FILES} * 8) / ${TIME_OBJECTS_DOWNLOAD}) / 1000) / 1000) / 1" | bc | sed 's/^\./0./'`


# Start of the 5th time measurement
TIME_ERASE_OBJECTS_START=`date +%s.%N`

# -----------------------------
# | Erase the Files (Objects) |
# -----------------------------
# If the "parallel" flag has been set, upload in parallel with GNU parallel
if [ "$PARALLEL" -eq 1 ] ; then
	echo -e "${GREEN}[OK] Downloading in parallel.${NC}"

else
# If the "parallel" flag has NOT been set, upload the files sequentially
	echo -e "${GREEN}[OK] Downloading in serial.${NC}"

	if aws $ENDPOINT_URL s3 rm  s3://$BUCKET --recursive; then
		echo -e "${GREEN}[OK] The objects has been deleted.${NC}"
     # Skip entire rest of loop.
     	break
    else
     echo -e "${YELLOW}[INFO] The bucket could not be deleted!${NC}"

    fi
fi


# End of the 5th time measurement
TIME_ERASE_OBJECTS_END=`date +%s.%N`

# Duration of the 5th time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_ERASE_OBJECTS=`echo "scale=3 ; (${TIME_ERASE_OBJECTS_END} - ${TIME_ERASE_OBJECTS_START})/1" | bc | sed 's/^\./0./'`



# Start of the 6th time measurement
TIME_ERASE_BUCKET_START=`date +%s.%N`

# ----------------------------
# | Erase bucket / container |
# ----------------------------
# If the "parallel" flag has been set, upload in parallel with GNU parallel
if [ "$PARALLEL" -eq 1 ] ; then
	echo -e "${GREEN}[OK]  in parallel.${NC}"

else
# If the "parallel" flag has NOT been set, upload the files sequentially
	echo -e "${GREEN}[OK]  in serial.${NC}"

	if aws $ENDPOINT_URL s3 rb  s3://$BUCKET --force; then
		echo -e "${GREEN}[OK] The bucket has been deleted.${NC}"
     # Skip entire rest of loop.
     	break
    else
     echo -e "${YELLOW}[INFO] The bucket could not be deleted!${NC}"

    fi
fi

# End of the 6th time measurement
TIME_ERASE_BUCKET_END=`date +%s.%N`

# Duration of the 6th time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_ERASE_BUCKET=`echo "scale=3 ; (${TIME_ERASE_BUCKET_END} - ${TIME_ERASE_BUCKET_START})/1" | bc | sed 's/^\./0./'`

echo 'Required time to create the bucket:                 '${TIME_CREATE_BUCKET} s
echo 'Required time to upload the files:                  '${TIME_OBJECTS_UPLOAD} s
echo 'Required time to fetch a list of files:             '${TIME_OBJECTS_LIST} s
echo 'Required time to download the files:                '${TIME_OBJECTS_DOWNLOAD} s
echo 'Required time to erase the objects:                 '${TIME_ERASE_OBJECTS} s
echo 'Required time to erase the bucket:                  '${TIME_ERASE_BUCKET} s

TIME_SUM=`echo "scale=3 ; (${TIME_CREATE_BUCKET} + ${TIME_OBJECTS_UPLOAD} + ${TIME_OBJECTS_LIST} + ${TIME_OBJECTS_DOWNLOAD} + ${TIME_ERASE_OBJECTS} + ${TIME_ERASE_BUCKET})/1" | bc | sed 's/^\./0./'`

echo 'Required time to perform all S3-related operations: '${TIME_SUM} s
echo ''
echo 'Bandwidth during the upload of the files:           '${BANDWIDTH_OBJECTS_UPLOAD} Mbps
echo 'Bandwidth during the download of the files:         '${BANDWIDTH_OBJECTS_DOWNLOAD} Mbps

#MINIO local network ON OPTANE 5 FILES, SERIAL OPERATIONS
#Required time to create the bucket:                 0.377 s
#Required time to upload the files:                  0.933 s
#Required time to fetch a list of files:             0.380 s
#Required time to download the files:                1.104 s
#Required time to erase the objects:                 0.508 s
#Required time to erase the bucket:                  0.916 s
#Required time to perform all S3-related operations: 4.218 s

#Bandwidth during the upload of the files:           42.872 Mbps
#Bandwidth during the download of the files:         36.231 Mbps 

#AWS REMOTE network  5 FILES, SERIAL OPERATIONS
#Required time to create the bucket:                 2.116 s
#Required time to upload the files:                  7.224 s
#Required time to fetch a list of files:             0.871 s
#Required time to download the files:                6.224 s
#Required time to erase the objects:                 1.321 s
#Required time to erase the bucket:                  1.309 s
#Required time to perform all S3-related operations: 19.065 s

#Bandwidth during the upload of the files:           5.537 Mbps
#Bandwidth during the download of the files:         6.426 Mbps
