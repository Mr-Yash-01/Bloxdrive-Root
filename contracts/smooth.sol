// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract Smooth {
    struct File {
        string name;
        string cid;
        uint256 size;
        uint256 createdAt;
        address owner;
        string fileType;
    }

    struct SharedFile {
        string name;
        string cid;
        uint256 size;
        uint256 createdAt;
        address owner;
        address sharedWith;
        string fileType;
    }

    struct Folder {
        string name;
        address owner;
        uint256 createdAt;
        File[] files;
        Folder[] folders;
    }

    struct userPart {
        Folder root;
        SharedFile[] sharedWithMe;
        SharedFile[] sharedToPeople;
    }

    mapping(address => userPart) private database;

    function checkUserRoot(address _user) public view returns (bool) {
        if (
            keccak256(abi.encodePacked(database[_user].root.name)) !=
            keccak256(abi.encodePacked("root"))
        ) {
            return false;
        }
        return true;
    }

    function initUserRoot(address _user) public returns (bool) {
        require(
            keccak256(abi.encodePacked(database[_user].root.name)) !=
                keccak256(abi.encodePacked("root")),
            "User already initialized"
        );
        database[_user].root.name = "root";
        database[_user].root.owner = _user;
        database[_user].root.createdAt = block.timestamp;
        return true;
    }

    function createFolder(
        string[] memory _path,
        string memory _folderName,
        address _user
    ) public {
        require(checkUserRoot(_user), "User root not initialized");

        Folder storage currentFolder = database[_user].root;
        for (uint256 i = 1; i < _path.length; i++) {
            bool folderExists = false;
            for (uint256 j = 0; j < currentFolder.folders.length; j++) {
                if (
                    keccak256(
                        abi.encodePacked(currentFolder.folders[j].name)
                    ) == keccak256(abi.encodePacked(_path[i]))
                ) {
                    currentFolder = currentFolder.folders[j];
                    folderExists = true;
                    break;
                }
            }
            require(folderExists, "Path does not exist");
        }
        currentFolder.folders.push();
        Folder storage newFolder = currentFolder.folders[
            currentFolder.folders.length - 1
        ];
        newFolder.name = _folderName;
        newFolder.owner = _user;
        newFolder.createdAt = block.timestamp;
    }

    function getFolderData(
        string[] memory _path,
        address _user
    ) public view returns (string memory) {
        require(checkUserRoot(_user), "User root not initialized");

        Folder storage currentFolder = database[_user].root;

        if (_path.length > 1) {
            for (uint256 i = 1; i < _path.length; i++) {
                bool folderExists = false;
                for (uint256 j = 0; j < currentFolder.folders.length; j++) {
                    if (
                        keccak256(
                            abi.encodePacked(currentFolder.folders[j].name)
                        ) == keccak256(abi.encodePacked(_path[i]))
                    ) {
                        currentFolder = currentFolder.folders[j];
                        folderExists = true;
                        break;
                    }
                }
                require(folderExists, "Path does not exist");
            }
        }

        // Constructing the folder data as a JSON string
        string memory folderData = string(
            abi.encodePacked(
                '{"name":"',
                currentFolder.name,
                '","owner":"',
                addressToString(currentFolder.owner),
                '","createdAt":"',
                uintToString(currentFolder.createdAt),
                '"'
            )
        );

        // Add files to JSON if they exist
        if (currentFolder.files.length > 0) {
            folderData = string(abi.encodePacked(folderData, ',"files":['));
            for (uint256 i = 0; i < currentFolder.files.length; i++) {
                File storage file = currentFolder.files[i];
                if (
                    bytes(file.name).length > 0 &&
                    bytes(file.cid).length > 0 &&
                    file.size > 0 &&
                    file.createdAt > 0 &&
                    file.owner != address(0)
                ) {
                    folderData = string(
                        abi.encodePacked(
                            folderData,
                            '{"name":"',
                            file.name,
                            '","cid":"',
                            file.cid,
                            '","size":"',
                            uintToString(file.size),
                            '","createdAt":"',
                            uintToString(file.createdAt),
                            '","owner":"',
                            addressToString(file.owner),
                            '","fileType":"',
                            file.fileType,
                            '"}'
                        )
                    );
                    if (i < currentFolder.files.length - 1) {
                        folderData = string(abi.encodePacked(folderData, ","));
                    }
                }
            }
            folderData = string(abi.encodePacked(folderData, "]"));
        }

        // Add folders to JSON if they exist
        if (currentFolder.folders.length > 0) {
            folderData = string(abi.encodePacked(folderData, ',"folders":['));
            for (uint256 i = 0; i < currentFolder.folders.length; i++) {
                Folder storage folder = currentFolder.folders[i];
                if (
                    bytes(folder.name).length > 0 &&
                    folder.owner != address(0) &&
                    folder.createdAt > 0
                ) {
                    folderData = string(
                        abi.encodePacked(
                            folderData,
                            '{"name":"',
                            folder.name,
                            '","owner":"',
                            addressToString(folder.owner),
                            '","createdAt":"',
                            uintToString(folder.createdAt),
                            '"}'
                        )
                    );
                    if (i < currentFolder.folders.length - 1) {
                        folderData = string(abi.encodePacked(folderData, ","));
                    }
                }
            }
            folderData = string(abi.encodePacked(folderData, "]"));
        }

        folderData = string(abi.encodePacked(folderData, "}"));

        return folderData;
    }

    function addressToString(
        address _addr
    ) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    function uintToString(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    struct FileData {
        string name;
        string cid;
        uint256 size;
        string fileType;
    }

    function createFiles(
        string[] memory _path,
        FileData[] memory _files,
        address _user
    ) public {
        require(checkUserRoot(_user), "User root not initialized");

        Folder storage currentFolder = database[_user].root;

        // Traverse to the target folder based on the path
        for (uint256 i = 1; i < _path.length; i++) {
            bool folderExists = false;
            for (uint256 j = 0; j < currentFolder.folders.length; j++) {
                if (
                    keccak256(
                        abi.encodePacked(currentFolder.folders[j].name)
                    ) == keccak256(abi.encodePacked(_path[i]))
                ) {
                    currentFolder = currentFolder.folders[j];
                    folderExists = true;
                    break;
                }
            }
            require(
                folderExists,
                string(
                    abi.encodePacked(
                        "Path does not exist at index ",
                        uintToString(i)
                    )
                )
            );
        }

        // Add multiple files to the target folder
        for (uint256 k = 0; k < _files.length; k++) {
            currentFolder.files.push(
                File({
                    name: _files[k].name,
                    cid: _files[k].cid,
                    size: _files[k].size,
                    createdAt: block.timestamp,
                    owner: _user,
                    fileType: _files[k].fileType
                })
            );
        }
    }

    function deleteFile(
        string[] memory _path,
        string memory _fileName,
        string memory _cid,
        address _user
    ) public {
        require(checkUserRoot(_user), "User root not initialized");

        // Delete from root folder
        Folder storage currentFolder = database[_user].root;

        // Traverse to the target folder
        for (uint256 i = 1; i < _path.length; i++) {
            bool folderExists = false;
            for (uint256 j = 0; j < currentFolder.folders.length; j++) {
                if (
                    keccak256(
                        abi.encodePacked(currentFolder.folders[j].name)
                    ) == keccak256(abi.encodePacked(_path[i]))
                ) {
                    currentFolder = currentFolder.folders[j];
                    folderExists = true;
                    break;
                }
            }
            require(
                folderExists,
                string(
                    abi.encodePacked(
                        "Path does not exist at index ",
                        uintToString(i)
                    )
                )
            );
        }

        // Find and remove the file from the files array
        bool fileExists = false;
        for (uint256 i = 0; i < currentFolder.files.length; i++) {
            if (
                keccak256(abi.encodePacked(currentFolder.files[i].name)) ==
                keccak256(abi.encodePacked(_fileName))
            ) {
                fileExists = true;
                // Shift elements left to remove the file
                for (uint256 j = i; j < currentFolder.files.length - 1; j++) {
                    currentFolder.files[j] = currentFolder.files[j + 1];
                }
                currentFolder.files.pop(); // Remove the last element
                break;
            }
        }
        require(fileExists, "File does not exist in root folder");

        // If CID is provided, delete from sharedToPeople
        if (bytes(_cid).length > 0) {
            fileExists = false;
            for (
                uint256 i = 0;
                i < database[_user].sharedToPeople.length;
                i++
            ) {
                if (
                    keccak256(
                        abi.encodePacked(database[_user].sharedToPeople[i].cid)
                    ) == keccak256(abi.encodePacked(_cid))
                ) {
                    fileExists = true;
                    // Shift elements left to remove the file
                    for (
                        uint256 j = i;
                        j < database[_user].sharedToPeople.length - 1;
                        j++
                    ) {
                        database[_user].sharedToPeople[j] = database[_user]
                            .sharedToPeople[j + 1];
                    }
                    database[_user].sharedToPeople.pop(); // Remove the last element
                    break;
                }
            }
            require(
                fileExists,
                "File with specified CID does not exist in sharedToPeople"
            );
        }
    }

    function deleteFileFromSharedToPeople(
        string memory _cid,
        address _user
    ) public {
        require(checkUserRoot(_user), "User root not initialized");

        bool fileExists = false;
        for (uint256 i = 0; i < database[_user].sharedToPeople.length; i++) {
            if (
                keccak256(
                    abi.encodePacked(database[_user].sharedToPeople[i].cid)
                ) == keccak256(abi.encodePacked(_cid))
            ) {
                fileExists = true;
                // Shift elements left to remove the file
                for (
                    uint256 j = i;
                    j < database[_user].sharedToPeople.length - 1;
                    j++
                ) {
                    database[_user].sharedToPeople[j] = database[_user]
                        .sharedToPeople[j + 1];
                }
                database[_user].sharedToPeople.pop(); // Remove the last element
                break;
            }
        }
        require(
            fileExists,
            "File with specified CID does not exist in sharedToPeople"
        );
    }

    function removeFileByFieldAndCid(string memory _cid, address _user) public {
        bool fileExists = false;
        for (uint256 i = 0; i < database[_user].sharedWithMe.length; i++) {
            if (
                keccak256(
                    abi.encodePacked(database[_user].sharedWithMe[i].cid)
                ) == keccak256(abi.encodePacked(_cid))
            ) {
                fileExists = true;
                // Shift elements left to remove the file
                for (
                    uint256 j = i;
                    j < database[_user].sharedWithMe.length - 1;
                    j++
                ) {
                    database[_user].sharedWithMe[j] = database[_user]
                        .sharedWithMe[j + 1];
                }
                database[_user].sharedWithMe.pop(); // Remove the last element
                break;
            }
        }
        require(
            fileExists,
            "File with specified CID does not exist in sharedWithMe"
        );
    }

    function deleteFolder(
        string[] memory _path,
        string memory _folderName,
        address _user
    ) public {
        require(checkUserRoot(_user), "User root not initialized");

        Folder storage currentFolder = database[_user].root;
        Folder storage parentFolder = currentFolder;

        // Traverse to the parent folder of the target folder
        for (uint256 i = 1; i < _path.length; i++) {
            bool folderExists3 = false;
            for (uint256 j = 0; j < currentFolder.folders.length; j++) {
                if (
                    keccak256(
                        abi.encodePacked(currentFolder.folders[j].name)
                    ) == keccak256(abi.encodePacked(_path[i]))
                ) {
                    parentFolder = currentFolder;
                    currentFolder = currentFolder.folders[j];
                    folderExists3 = true;
                    break;
                }
            }
            require(
                folderExists3,
                string(
                    abi.encodePacked(
                        "Path does not exist at index ",
                        uintToString(i)
                    )
                )
            );
        }

        // Find and remove the folder from the folders array
        bool folderExists4 = false;
        for (uint256 i = 0; i < parentFolder.folders.length; i++) {
            if (
                keccak256(abi.encodePacked(parentFolder.folders[i].name)) ==
                keccak256(abi.encodePacked(_folderName))
            ) {
                folderExists4 = true;
                // Shift elements left to remove the folder
                for (uint256 j = i; j < parentFolder.folders.length - 1; j++) {
                    parentFolder.folders[j] = parentFolder.folders[j + 1];
                }
                parentFolder.folders.pop(); // Remove the last element
                break;
            }
        }
        require(folderExists4, "Folder does not exist");
    }

    function giveFileAccess(
    address owner,
    address to,
    string memory name,
    string memory cid,
    uint256 size,
    uint256 createdAt,
    string memory fileType
) public {
    SharedFile memory newFile = SharedFile({
        name: name,
        cid: cid,
        size: size,
        createdAt: createdAt,
        owner: owner,
        sharedWith: to,
        fileType: fileType
    });

    database[owner].sharedToPeople.push(newFile);
    database[to].sharedWithMe.push(newFile);
}

function getSharedData(address _user) public view returns (string memory) {
    require(checkUserRoot(_user), "User root not initialized");

    SharedFile[] storage sharedToPeople = database[_user].sharedToPeople;
    SharedFile[] storage sharedWithMe = database[_user].sharedWithMe;

    // Constructing the sharedToPeople data as a JSON string
    string memory sharedToPeopleData = "[";
    for (uint256 i = 0; i < sharedToPeople.length; i++) {
        SharedFile storage data = sharedToPeople[i];
        string memory dataJson = string(
            abi.encodePacked(
                '{"name":"',
                data.name,
                '","owner":"',
                addressToString(data.owner),
                '","createdAt":"',
                uintToString(data.createdAt),
                '","to":"',
                addressToString(data.sharedWith),
                '","cid":"',
                data.cid,
                '","size":"',
                uintToString(data.size),
                '","fileType":"',
                data.fileType,
                '"}'
            )
        );

        sharedToPeopleData = string(
            abi.encodePacked(sharedToPeopleData, dataJson)
        );
        if (i < sharedToPeople.length - 1) {
            sharedToPeopleData = string(
                abi.encodePacked(sharedToPeopleData, ",")
            );
        }
    }
    sharedToPeopleData = string(abi.encodePacked(sharedToPeopleData, "]"));

    // Constructing the sharedWithMe data as a JSON string
    string memory sharedWithMeData = "[";
    for (uint256 i = 0; i < sharedWithMe.length; i++) {
        SharedFile storage data = sharedWithMe[i];
        string memory dataJson = string(
            abi.encodePacked(
                '{"name":"',
                data.name,
                '","owner":"',
                addressToString(data.owner),
                '","createdAt":"',
                uintToString(data.createdAt),
                '","to":"',
                addressToString(data.sharedWith),
                '","cid":"',
                data.cid,
                '","size":"',
                uintToString(data.size),
                '","fileType":"',
                data.fileType,
                '"}'
            )
        );

        sharedWithMeData = string(
            abi.encodePacked(sharedWithMeData, dataJson)
        );
        if (i < sharedWithMe.length - 1) {
            sharedWithMeData = string(
                abi.encodePacked(sharedWithMeData, ",")
            );
        }
    }
    sharedWithMeData = string(abi.encodePacked(sharedWithMeData, "]"));

    // Combine both JSON strings into one
    string memory combinedData = string(
        abi.encodePacked(
            '{"sharedToPeople":',
            sharedToPeopleData,
            ',"sharedWithMe":',
            sharedWithMeData,
            "}"
        )
    );

    return combinedData;
}

    

    
}
