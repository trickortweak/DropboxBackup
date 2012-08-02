#!/bin/bash

# Set the source & dest directories -- (update to reflect your locations)
src=/Your/Pictures/Folder/
dest=/Your/Dropbox/Folder/

# Change the directory to the source, send the user an error if failure occurs (user can't read directory)
cd "$src" || { echo "Failed to cd to $src, exiting..."; exit 1; }

# Sync the directory structure using rsync, uses rsync filter rules to 
# ignore all files and only work on directories
# Includes support for hidden picasa files
echo "Syncing directories and picasa.ini files..."
rsync --archive --verbose --delete -f "+ */" -f"+ .picasa.ini" -f "- *" "$src/" "$dest"

echo "Syncing pictures..."
# Find all image files (JPG, CR2, etc.), check if equivalent file exists in parallel directory, 
# if not, create it
# In the case of a raw file (CR2), create an associated JPG file

find . -iname '*.JPG' -o -iname '*.CR2' | while read file
do
    # Get the filename
    filename=$(basename ${file})
    
    # Get the extension of the file
	extension=${filename##*.}
	
	# If it's a raw filetype, change the destination file to "JPG"
    if [[ "${extension}" = "CR2" ]]; then
    	#remove extension
    	new_file=${file%.*}
    	dest_file="$dest/${new_file#./}.jpg"
	else
		dest_file="$dest/${file#./}"
	fi
	
	# Check if the file doesn't exist at the destination
	if [[ ! -e "$dest_file" && ! -s "$dest_file" ]]; then
		echo "Converting $file to $dest_file" 
		
		# Convert the image file to jpg
		# -quiet: don't show errors
		# -resize: Maximum width or height of pixels to downsize to
		# -quality: JPG compression quality
		convert -quiet -resize "2000>" -quality 75 "$file" "$dest_file"
		echo "convert -quiet -resize \"2000>\" -quality 75 \"$file\" \"$dest_file\""
		# Check if convert correctly resized and copied the file
		if [[ $? -ne 0 ]]; then 
			echo "Failed to create file $dest_file";
		else
			# Get the creation date of the original file
			creation_date=`stat -t "%Y%m%d%H%M" -f "%SB" "$file"`
			
			# "stamp" the new picture with the creation date of the original
			touch -t $creation_date "$dest_file"
		fi
	else
		echo "Skipping $file as it already exists at $dest_file"
	fi
done

# Check to see if any files need to be removed
echo "Syncing files on Cloud Service"
cd ${dest}
find . -iname '*.JPG' | while read file
do
	# Get the filename
    filename=$(basename ${file})
	# Check if the file does not exist in the source directory    
    if [[ ! -e "$src/${file#./}"  ]]; then
    	
    	# Check to see if the file was renamed (in case it was a raw file that was converted to a JPG)
    	file_base=${file%.*}
    	if [[ ! -e "$src/${file_base#./}.CR2" ]]; then
        	rm "${file}"
        fi
    fi
done

# Cleanup any empty directories if all pictures were removed from the destination directory
rsync --archive --verbose --delete -f "+ */" -f "- *" "$src/" "$dest"
