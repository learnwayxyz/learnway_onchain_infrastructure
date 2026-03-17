// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILearnWayCertificate {
    function addCourse(uint256 courseId, string calldata courseName, string calldata instructorName) external;
    function updateCourseStatus(uint256 courseId, bool active) external;
    function mintCertificate(address user, uint256 courseId, string calldata metadataURI) external;
    function hasCertificate(address user, uint256 courseId) external view returns (bool);
    function getCertificateByToken(uint256 tokenId) external view returns (uint256, address, uint256, string memory);
    function getCertificate(address user, uint256 courseId) external view returns (bool, uint256, uint256, string memory);
    function getUserCertificates(address user) external view returns (uint256[] memory);
    function getCourseInfo(uint256 courseId) external view returns (string memory, string memory, bool);
}
