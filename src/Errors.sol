// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

// --- Access Control Errors ---
error UnauthorizedAdmin();
error UnauthorizedManager();
error UnauthorizedModerator();
error UnauthorizedEmergency();
error UnauthorizedPauser();
error UnauthorizedAdminOrManager();
error UnauthorizedMinter();

// --- Certificate Errors ---
error InvalidCourseId();
error CourseAlreadyExists();
error CourseNotActive();
error CertificateAlreadyMinted();
error CertificateNonTransferable();
error EmptyCourseName();
error EmptyInstructorName();
error EmptyMetadataURI();
error InvalidAddress();
