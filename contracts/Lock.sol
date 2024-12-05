// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract Lock {
    struct File {
        string name;
        string cid; // IPFS CID
        uint256 size; // File size in bytes
        string fileType; // Type of the file (e.g., image, pdf, doc)
        address owner;
        uint256 createdAt;
    }

    struct Folder {
        string name;
        address owner;
        uint256 createdAt;
        string[] fileNames; // List of file/folder names within this folder
        mapping(string => File) files; // Nested files
        mapping(string => Folder) folders; // Nested folders
        File[] sharedWithMe; // Files shared with the user
    }

    mapping(address => Folder) private userRoot; // Root folder for each user

    constructor() {
        _initializeUserRoot(msg.sender);
    }

    function _initializeUserRoot(address user) internal {
        if (bytes(userRoot[user].name).length == 0) {
            Folder storage rootFolder = userRoot[user];
            rootFolder.name = "My Space";
            rootFolder.owner = user;
            rootFolder.createdAt = block.timestamp;
        }
    }

    function checkUserRootExists() public view returns (string memory) {
        if (bytes(userRoot[msg.sender].name).length == 0) {
            return "Base does not exist";
        }
        return "Base already exists";
    }

    function initializeUserRoot() public returns (string memory) {
        if (bytes(userRoot[msg.sender].name).length == 0) {
            _initializeUserRoot(msg.sender);
            return "Base initialized";
        }
        return "Base already initialized";
    }

    function createFolder(
        string[] memory path,
        string memory folderName
    ) public {
        _initializeUserRoot(msg.sender);
        Folder storage currentFolder = userRoot[msg.sender];

        // Traverse the path to reach the target folder
        for (uint256 i = 0; i < path.length; i++) {
            currentFolder = currentFolder.folders[path[i]];
        }

        // Check if the folder or file with the same name already exists
        require(
            bytes(currentFolder.folders[folderName].name).length == 0,
            "Folder already exists"
        );
        require(
            bytes(currentFolder.files[folderName].name).length == 0,
            "A file with the same name already exists"
        );

        // Create the new folder
        Folder storage newFolder = currentFolder.folders[folderName];
        newFolder.name = folderName;
        newFolder.owner = msg.sender;
        newFolder.createdAt = block.timestamp;
        currentFolder.fileNames.push(folderName);
    }

    function uploadFile(
        string[] memory path,
        string memory fileName,
        string memory cid,
        uint256 size,
        string memory fileType
    ) public {
        _initializeUserRoot(msg.sender);
        Folder storage currentFolder = userRoot[msg.sender];

        // Traverse the path to reach the target folder
        for (uint256 i = 0; i < path.length; i++) {
            currentFolder = currentFolder.folders[path[i]];
        }

        // Check if the file or folder with the same name already exists
        require(
            bytes(currentFolder.files[fileName].name).length == 0,
            "File already exists"
        );
        require(
            bytes(currentFolder.folders[fileName].name).length == 0,
            "A folder with the same name already exists"
        );

        // Create the new file
        File storage newFile = currentFolder.files[fileName];
        newFile.name = fileName;
        newFile.cid = cid;
        newFile.size = size;
        newFile.fileType = fileType;
        newFile.owner = msg.sender;
        newFile.createdAt = block.timestamp;
        currentFolder.fileNames.push(fileName);
    }

    struct FileInfo {
        string name;
        string cid;
        uint256 size;
        string fileType;
        uint256 createdAt;
    }

    struct FolderInfo {
        string name;
        uint256 createdAt;
        FileInfo[] files;
        string[] subFolderNames;
        FileInfo[] sharedWithMe;
    }

    function getFolderData(
        string[] memory path
    ) public view returns (FolderInfo memory) {
        Folder storage currentFolder = userRoot[msg.sender];

        // Traverse the path to reach the target folder
        for (uint256 i = 0; i < path.length; i++) {
            // Check if the folder exists
            if (bytes(currentFolder.folders[path[i]].name).length == 0) {
                revert("Folder does not exist");
            }
            currentFolder = currentFolder.folders[path[i]];
        }

        return _getFolderInfo(currentFolder);
    }

    function _getFolderInfo(
        Folder storage folder
    ) internal view returns (FolderInfo memory) {
        uint256 fileCount = 0;
        uint256 folderCount = 0;

        // Count files and folders
        for (uint256 i = 0; i < folder.fileNames.length; i++) {
            string memory fileName = folder.fileNames[i];
            if (bytes(folder.files[fileName].name).length != 0) {
                fileCount++;
            } else {
                folderCount++;
            }
        }

        FileInfo[] memory files = new FileInfo[](fileCount);
        string[] memory subFolderNames = new string[](folderCount);
        FileInfo[] memory sharedFiles = new FileInfo[](
            folder.sharedWithMe.length
        );

        uint256 fileIndex = 0;
        uint256 folderIndex = 0;

        for (uint256 i = 0; i < folder.fileNames.length; i++) {
            string memory fileName = folder.fileNames[i];
            if (bytes(folder.files[fileName].name).length != 0) {
                File storage file = folder.files[fileName];
                files[fileIndex++] = FileInfo(
                    file.name,
                    file.cid,
                    file.size,
                    file.fileType,
                    file.createdAt
                );
            } else {
                subFolderNames[folderIndex++] = fileName;
            }
        }

        for (uint256 i = 0; i < folder.sharedWithMe.length; i++) {
            File storage sharedFile = folder.sharedWithMe[i];
            sharedFiles[i] = FileInfo(
                sharedFile.name,
                sharedFile.cid,
                sharedFile.size,
                sharedFile.fileType,
                sharedFile.createdAt
            );
        }

        return
            FolderInfo(
                folder.name,
                folder.createdAt,
                files,
                subFolderNames,
                sharedFiles
            );
    }

    function updateFile(
        string[] memory path,
        string memory fileName,
        string memory newCid,
        uint256 newSize,
        string memory newFileName,
        string memory newFileType
    ) public {
        _initializeUserRoot(msg.sender);
        Folder storage currentFolder = userRoot[msg.sender];

        // Traverse the path to reach the target folder
        for (uint256 i = 0; i < path.length; i++) {
            currentFolder = currentFolder.folders[path[i]];
        }

        // Check if the file exists
        require(
            bytes(currentFolder.files[fileName].name).length != 0,
            "File does not exist"
        );

        // Check if the new file name already exists
        if (
            bytes(newFileName).length != 0 &&
            keccak256(bytes(newFileName)) != keccak256(bytes(fileName))
        ) {
            require(
                bytes(currentFolder.files[newFileName].name).length == 0,
                "New file name already exists"
            );
            require(
                bytes(currentFolder.folders[newFileName].name).length == 0,
                "A folder with the new file name already exists"
            );
        }

        // Update the file data
        File storage fileToUpdate = currentFolder.files[fileName];
        fileToUpdate.cid = newCid;
        fileToUpdate.size = newSize;
        fileToUpdate.fileType = newFileType;

        // Update the file name if a new name is provided
        if (
            bytes(newFileName).length != 0 &&
            keccak256(bytes(newFileName)) != keccak256(bytes(fileName))
        ) {
            // Remove the old file name from the fileNames array
            for (uint256 i = 0; i < currentFolder.fileNames.length; i++) {
                if (
                    keccak256(bytes(currentFolder.fileNames[i])) ==
                    keccak256(bytes(fileName))
                ) {
                    currentFolder.fileNames[i] = newFileName;
                    break;
                }
            }

            // Update the file mapping
            currentFolder.files[newFileName] = fileToUpdate;
            delete currentFolder.files[fileName];
        }
    }

    function deleteItem(string[] memory path, string memory itemName) public {
        _initializeUserRoot(msg.sender);
        Folder storage currentFolder = userRoot[msg.sender];

        // Traverse the path to reach the target folder
        for (uint256 i = 0; i < path.length; i++) {
            currentFolder = currentFolder.folders[path[i]];
        }

        // Check if the item is a file or a folder and delete it
        if (bytes(currentFolder.files[itemName].name).length != 0) {
            // It's a file, delete it
            delete currentFolder.files[itemName];
        } else if (bytes(currentFolder.folders[itemName].name).length != 0) {
            // It's a folder, delete it
            delete currentFolder.folders[itemName];
        } else {
            revert("Item does not exist");
        }

        // Remove the item name from the fileNames array
        for (uint256 i = 0; i < currentFolder.fileNames.length; i++) {
            if (
                keccak256(bytes(currentFolder.fileNames[i])) ==
                keccak256(bytes(itemName))
            ) {
                currentFolder.fileNames[i] = currentFolder.fileNames[
                    currentFolder.fileNames.length - 1
                ];
                currentFolder.fileNames.pop();
                break;
            }
        }
    }

    function shareFileWithUser(
        string[] memory path,
        string memory fileName,
        address recipient
    ) public {
        _initializeUserRoot(msg.sender);
        Folder storage currentFolder = userRoot[msg.sender];

        // Traverse the path to reach the target folder
        for (uint256 i = 0; i < path.length; i++) {
            currentFolder = currentFolder.folders[path[i]];
        }

        // Check if the file exists
        require(
            bytes(currentFolder.files[fileName].name).length != 0,
            "File does not exist"
        );

        // Get the file to be shared
        File storage fileToShare = currentFolder.files[fileName];

        // Initialize recipient's root folder if not already initialized
        _initializeUserRoot(recipient);

        // Add the file to the recipient's sharedWithMe array
        userRoot[recipient].sharedWithMe.push(fileToShare);
    }

    function getSharedWithMeFiles() public view returns (FileInfo[] memory) {
        Folder storage currentFolder = userRoot[msg.sender];
        FileInfo[] memory sharedFiles = new FileInfo[](
            currentFolder.sharedWithMe.length
        );

        for (uint256 i = 0; i < currentFolder.sharedWithMe.length; i++) {
            File storage sharedFile = currentFolder.sharedWithMe[i];
            sharedFiles[i] = FileInfo(
                sharedFile.name,
                sharedFile.cid,
                sharedFile.size,
                sharedFile.fileType,
                sharedFile.createdAt
            );
        }

        return sharedFiles;
    }
}