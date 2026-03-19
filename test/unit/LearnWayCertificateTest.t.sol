// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LearnWayCertificate} from "../../src/LearnWayCertificate.sol";
import "../utils/BaseTest.t.sol";
import "../utils/Mocks.t.sol";

// ============================================================
//  Initialize
// ============================================================

contract LearnWayCertificateTest_Initialize is BaseTest {
    LearnWayCertificate uninitializedCert;

    function setUp() public override {
        super.setUp();
        LearnWayCertificate impl = new LearnWayCertificate();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
        uninitializedCert = LearnWayCertificate(address(proxy));
        vm.label(address(uninitializedCert), "UninitializedCertificate");
    }

    // --- Access Control ---

    function test_RevertWhen_AdminAddressIsZero() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        uninitializedCert.initialize(address(0));
    }

    // --- Preconditions ---

    function test_RevertWhen_AlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        certificateContract.initialize(address(adminContract));
    }

    // --- Happy Path ---

    function test_SetsAdminContractOnInitialize() public {
        assertEq(address(certificateContract.adminContract()), address(adminContract));
    }

    function test_SetsCorrectNameAndSymbol() public {
        assertEq(certificateContract.name(), "LearnWay Certificate");
        assertEq(certificateContract.symbol(), "LWC");
    }

    // --- Upgrade Safety ---

    function test_InitializerDisabledOnImplementationContract() public {
        LearnWayCertificate impl = new LearnWayCertificate();
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        impl.initialize(address(adminContract));
    }
}

// ============================================================
//  AddCourse
// ============================================================

contract LearnWayCertificateTest_AddCourse is BaseTest {
    event CourseAdded(uint256 indexed courseId, string courseName, string instructorName, bool status);

    // --- Access Control ---

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
    }

    function test_RevertWhen_CallerIsManager() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
    }

    // --- Input Validation ---

    function test_RevertWhen_CourseNameIsEmpty() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("EmptyCourseName()"));
        certificateContract.addCourse(1, "", "Dr. Mensah");
    }

    function test_RevertWhen_InstructorNameIsEmpty() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("EmptyInstructorName()"));
        certificateContract.addCourse(1, "Blockchain 101", "");
    }

    // --- Preconditions ---

    function test_RevertWhen_CourseAlreadyExists() public {
        vm.prank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("CourseAlreadyExists()"));
        certificateContract.addCourse(1, "Different Name", "Different Instructor");
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(pauser);
        certificateContract.pause();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
    }

    // --- Happy Path / Effects ---

    function test_AddsCourseSuccessfully() public {
        vm.prank(admin);
        certificateContract.addCourse(42, "Blockchain 101", "Dr. Mensah");

        assertTrue(certificateContract.courseExists(42));
        (string memory name, string memory instructor, bool active) = certificateContract.getCourseInfo(42);
        assertEq(name, "Blockchain 101");
        assertEq(instructor, "Dr. Mensah");
        assertTrue(active);
    }

    function test_AddsMultipleCoursesWithDifferentIds() public {
        vm.startPrank(admin);
        certificateContract.addCourse(1, "Course A", "Instructor A");
        certificateContract.addCourse(100, "Course B", "Instructor B");
        certificateContract.addCourse(999, "Course C", "Instructor C");
        vm.stopPrank();

        assertTrue(certificateContract.courseExists(1));
        assertTrue(certificateContract.courseExists(100));
        assertTrue(certificateContract.courseExists(999));
    }

    // --- Events ---

    function test_EmitsCourseAddedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit CourseAdded(1, "Blockchain 101", "Dr. Mensah", true);

        vm.prank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
    }

    // --- Fuzz ---

    function testFuzz_AddCourseWithRandomId(uint256 courseId) public {
        vm.prank(admin);
        certificateContract.addCourse(courseId, "Fuzz Course", "Fuzz Instructor");
        assertTrue(certificateContract.courseExists(courseId));
    }
}

// ============================================================
//  UpdateCourseStatus
// ============================================================

contract LearnWayCertificateTest_UpdateCourseStatus is BaseTest {
    event CourseStatusUpdated(uint256 indexed courseId, bool active, bool status);

    function setUp() public override {
        super.setUp();
        vm.prank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
    }

    // --- Access Control ---

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        certificateContract.updateCourseStatus(1, false);
    }

    // --- Input Validation ---

    function test_RevertWhen_CourseDoesNotExist() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidCourseId()"));
        certificateContract.updateCourseStatus(999, false);
    }

    // --- Preconditions ---

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(pauser);
        certificateContract.pause();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        certificateContract.updateCourseStatus(1, false);
    }

    // --- Happy Path / Effects ---

    function test_DeactivatesCourse() public {
        vm.prank(admin);
        certificateContract.updateCourseStatus(1, false);

        (,, bool active) = certificateContract.getCourseInfo(1);
        assertFalse(active);
    }

    function test_ReactivatesCourse() public {
        vm.startPrank(admin);
        certificateContract.updateCourseStatus(1, false);
        certificateContract.updateCourseStatus(1, true);
        vm.stopPrank();

        (,, bool active) = certificateContract.getCourseInfo(1);
        assertTrue(active);
    }

    // --- Events ---

    function test_EmitsCourseStatusUpdatedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit CourseStatusUpdated(1, false, true);

        vm.prank(admin);
        certificateContract.updateCourseStatus(1, false);
    }
}

// ============================================================
//  MintCertificate
// ============================================================

contract LearnWayCertificateTest_MintCertificate is BaseTest {
    event CertificateMinted(
        address indexed user, uint256 indexed courseId, uint256 tokenId, string metadataURI, bool status
    );

    string constant METADATA_URI = "ipfs://QmTestHash123";

    function setUp() public override {
        super.setUp();
        vm.prank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
    }

    // --- Access Control ---

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdminOrManager()"));
        certificateContract.mintCertificate(user1, 1, METADATA_URI);
    }

    function test_AdminCanMintCertificate() public {
        vm.prank(admin);
        certificateContract.mintCertificate(user1, 1, METADATA_URI);
        assertTrue(certificateContract.hasCertificate(user1, 1));
    }

    function test_ManagerCanMintCertificate() public {
        vm.prank(manager);
        certificateContract.mintCertificate(user1, 1, METADATA_URI);
        assertTrue(certificateContract.hasCertificate(user1, 1));
    }

    // --- Input Validation ---

    function test_RevertWhen_UserAddressIsZero() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        certificateContract.mintCertificate(address(0), 1, METADATA_URI);
    }

    function test_RevertWhen_CourseDoesNotExist() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidCourseId()"));
        certificateContract.mintCertificate(user1, 999, METADATA_URI);
    }

    function test_RevertWhen_MetadataURIIsEmpty() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("EmptyMetadataURI()"));
        certificateContract.mintCertificate(user1, 1, "");
    }

    // --- Preconditions ---

    function test_RevertWhen_CourseIsNotActive() public {
        vm.startPrank(admin);
        certificateContract.updateCourseStatus(1, false);

        vm.expectRevert(abi.encodeWithSignature("CourseNotActive()"));
        certificateContract.mintCertificate(user1, 1, METADATA_URI);
        vm.stopPrank();
    }

    function test_RevertWhen_CertificateAlreadyMinted() public {
        vm.startPrank(admin);
        certificateContract.mintCertificate(user1, 1, METADATA_URI);

        vm.expectRevert(abi.encodeWithSignature("CertificateAlreadyMinted()"));
        certificateContract.mintCertificate(user1, 1, "ipfs://QmDifferent");
        vm.stopPrank();
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(pauser);
        certificateContract.pause();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        certificateContract.mintCertificate(user1, 1, METADATA_URI);
    }

    // --- Happy Path ---

    function test_MintsTokenToUser() public {
        vm.prank(admin);
        certificateContract.mintCertificate(user1, 1, METADATA_URI);

        (bool exists, uint256 tokenId,,) = certificateContract.getCertificate(user1, 1);
        assertTrue(exists);
        assertEq(certificateContract.ownerOf(tokenId), user1);
        assertEq(certificateContract.balanceOf(user1), 1);
    }

    // --- Effects ---

    function test_StoresCertificateData() public {
        vm.prank(admin);
        certificateContract.mintCertificate(user1, 1, METADATA_URI);

        (, uint256 tokenId,,) = certificateContract.getCertificate(user1, 1);
        (uint256 courseId, address recipient, uint256 mintedAt, string memory uri) =
            certificateContract.getCertificateByToken(tokenId);
        assertEq(courseId, 1);
        assertEq(recipient, user1);
        assertEq(mintedAt, block.timestamp);
        assertEq(uri, METADATA_URI);
    }

    function test_SetsHasCertificateFlag() public {
        assertFalse(certificateContract.hasCertificate(user1, 1));

        vm.prank(admin);
        certificateContract.mintCertificate(user1, 1, METADATA_URI);

        assertTrue(certificateContract.hasCertificate(user1, 1));
    }

    function test_TracksCertificatesPerUser() public {
        vm.startPrank(admin);
        certificateContract.addCourse(2, "Course B", "Instructor B");
        certificateContract.mintCertificate(user1, 1, METADATA_URI);
        certificateContract.mintCertificate(user1, 2, "ipfs://QmHash2");
        vm.stopPrank();

        uint256[] memory certs = certificateContract.getUserCertificates(user1);
        assertEq(certs.length, 2);
        assertEq(certificateContract.ownerOf(certs[0]), user1);
        assertEq(certificateContract.ownerOf(certs[1]), user1);
    }

    function test_EachMintProducesUniqueTokenForCorrectUser() public {
        vm.startPrank(admin);
        certificateContract.addCourse(2, "Course B", "Instructor B");
        certificateContract.mintCertificate(user1, 1, METADATA_URI);
        certificateContract.mintCertificate(user2, 2, "ipfs://QmHash2");
        vm.stopPrank();

        (, uint256 tokenId1,,) = certificateContract.getCertificate(user1, 1);
        (, uint256 tokenId2,,) = certificateContract.getCertificate(user2, 2);

        assertTrue(tokenId1 != tokenId2);
        assertEq(certificateContract.ownerOf(tokenId1), user1);
        assertEq(certificateContract.ownerOf(tokenId2), user2);
    }

    // --- Events ---

    function test_EmitsCertificateMintedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit CertificateMinted(user1, 1, 1, METADATA_URI, true);

        vm.prank(admin);
        certificateContract.mintCertificate(user1, 1, METADATA_URI);
    }

    // --- Edge Cases ---

    function test_DifferentUsersCanMintSameCourse() public {
        vm.startPrank(admin);
        certificateContract.mintCertificate(user1, 1, "ipfs://QmHash1");
        certificateContract.mintCertificate(user2, 1, "ipfs://QmHash2");
        vm.stopPrank();

        assertTrue(certificateContract.hasCertificate(user1, 1));
        assertTrue(certificateContract.hasCertificate(user2, 1));
    }

    function test_SameUserCanMintDifferentCourses() public {
        vm.startPrank(admin);
        certificateContract.addCourse(2, "Course B", "Instructor B");
        certificateContract.mintCertificate(user1, 1, "ipfs://QmHash1");
        certificateContract.mintCertificate(user1, 2, "ipfs://QmHash2");
        vm.stopPrank();

        assertTrue(certificateContract.hasCertificate(user1, 1));
        assertTrue(certificateContract.hasCertificate(user1, 2));
    }

    // --- Fuzz ---

    function testFuzz_MintCertificateWithRandomCourseId(uint256 courseId) public {
        vm.assume(courseId != 1); // course 1 already added in setUp
        vm.startPrank(admin);
        certificateContract.addCourse(courseId, "Fuzz Course", "Fuzz Instructor");
        certificateContract.mintCertificate(user1, courseId, METADATA_URI);
        vm.stopPrank();

        assertTrue(certificateContract.hasCertificate(user1, courseId));
    }
}

// ============================================================
//  TokenURI
// ============================================================

contract LearnWayCertificateTest_TokenURI is BaseTest {
    string constant METADATA_URI = "ipfs://QmTestHash123";

    function setUp() public override {
        super.setUp();
        vm.startPrank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
        certificateContract.mintCertificate(user1, 1, METADATA_URI);
        vm.stopPrank();
    }

    function test_ReturnsStoredIPFSUri() public view {
        (, uint256 tokenId,,) = certificateContract.getCertificate(user1, 1);
        assertEq(certificateContract.tokenURI(tokenId), METADATA_URI);
    }

    function test_RevertWhen_TokenDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 999));
        certificateContract.tokenURI(999);
    }
}

// ============================================================
//  GetCertificate
// ============================================================

contract LearnWayCertificateTest_GetCertificate is BaseTest {
    string constant METADATA_URI = "ipfs://QmTestHash123";

    function setUp() public override {
        super.setUp();
        vm.startPrank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
        certificateContract.mintCertificate(user1, 1, METADATA_URI);
        vm.stopPrank();
    }

    function test_ReturnsExistingCertificate() public view {
        (bool exists, uint256 tokenId, uint256 mintedAt, string memory uri) =
            certificateContract.getCertificate(user1, 1);

        assertTrue(exists);
        assertTrue(tokenId != 0);
        assertEq(mintedAt, block.timestamp);
        assertEq(uri, METADATA_URI);
    }

    function test_ReturnsFalseForNonExistingCertificate() public view {
        (bool exists, uint256 tokenId, uint256 mintedAt, string memory uri) =
            certificateContract.getCertificate(user2, 1);

        assertFalse(exists);
        assertEq(tokenId, 0);
        assertEq(mintedAt, 0);
        assertEq(uri, "");
    }

    function test_GetCertificateByTokenReturnsCorrectData() public view {
        (uint256 courseId, address recipient, uint256 mintedAt, string memory uri) =
            certificateContract.getCertificateByToken(1);

        assertEq(courseId, 1);
        assertEq(recipient, user1);
        assertEq(mintedAt, block.timestamp);
        assertEq(uri, METADATA_URI);
    }

    function test_GetCertificateByToken_RevertWhen_TokenDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 999));
        certificateContract.getCertificateByToken(999);
    }
}

// ============================================================
//  GetUserCertificates
// ============================================================

contract LearnWayCertificateTest_GetUserCertificates is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.startPrank(admin);
        certificateContract.addCourse(1, "Course A", "Instructor A");
        certificateContract.addCourse(2, "Course B", "Instructor B");
        certificateContract.addCourse(3, "Course C", "Instructor C");
        vm.stopPrank();
    }

    function test_ReturnsEmptyArrayForUserWithNoCertificates() public view {
        uint256[] memory certs = certificateContract.getUserCertificates(user1);
        assertEq(certs.length, 0);
    }

    function test_ReturnsSingleCertificate() public {
        vm.prank(admin);
        certificateContract.mintCertificate(user1, 1, "ipfs://QmHash1");

        uint256[] memory certs = certificateContract.getUserCertificates(user1);
        assertEq(certs.length, 1);
        assertEq(certificateContract.ownerOf(certs[0]), user1);
    }

    function test_ReturnsMultipleCertificates() public {
        vm.startPrank(admin);
        certificateContract.mintCertificate(user1, 1, "ipfs://QmHash1");
        certificateContract.mintCertificate(user1, 2, "ipfs://QmHash2");
        certificateContract.mintCertificate(user1, 3, "ipfs://QmHash3");
        vm.stopPrank();

        uint256[] memory certs = certificateContract.getUserCertificates(user1);
        assertEq(certs.length, 3);
        for (uint256 i = 0; i < certs.length; i++) {
            assertEq(certificateContract.ownerOf(certs[i]), user1);
        }
    }
}

// ============================================================
//  SoulboundTransfer
// ============================================================

contract LearnWayCertificateTest_SoulboundTransfer is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.startPrank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
        certificateContract.mintCertificate(user1, 1, "ipfs://QmTestHash");
        vm.stopPrank();
    }

    function test_RevertWhen_TransferFromCalled() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CertificateNonTransferable()"));
        certificateContract.transferFrom(user1, user2, 1);
    }

    function test_RevertWhen_SafeTransferFromCalled() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CertificateNonTransferable()"));
        certificateContract.safeTransferFrom(user1, user2, 1);
    }

    function test_RevertWhen_SafeTransferFromWithDataCalled() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CertificateNonTransferable()"));
        certificateContract.safeTransferFrom(user1, user2, 1, "");
    }

    function test_MintingStillWorks() public {
        vm.startPrank(admin);
        certificateContract.addCourse(2, "Course B", "Instructor B");
        certificateContract.mintCertificate(user2, 2, "ipfs://QmHash2");
        vm.stopPrank();

        (, uint256 tokenId,,) = certificateContract.getCertificate(user2, 2);
        assertEq(certificateContract.ownerOf(tokenId), user2);
    }
}

// ============================================================
//  Pause
// ============================================================

contract LearnWayCertificateTest_Pause is BaseTest {
    // --- Access Control ---

    function test_AdminCanPause() public {
        vm.prank(admin);
        certificateContract.pause();
        assertTrue(certificateContract.paused());
    }

    function test_PauserCanPause() public {
        vm.prank(pauser);
        certificateContract.pause();
        assertTrue(certificateContract.paused());
    }

    function test_RevertWhen_StrangerTriesToPause() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedPauser()"));
        certificateContract.pause();
    }

    function test_RevertWhen_StrangerTriesToUnpause() public {
        vm.prank(admin);
        certificateContract.pause();

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        certificateContract.unpause();
    }

    function test_OnlyAdminCanUnpause() public {
        vm.prank(admin);
        certificateContract.pause();

        vm.prank(pauser);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        certificateContract.unpause();
    }

    function test_AdminCanUnpause() public {
        vm.prank(admin);
        certificateContract.pause();

        vm.prank(admin);
        certificateContract.unpause();
        assertFalse(certificateContract.paused());
    }

    // --- Effects ---

    function test_MintingBlockedWhenPaused() public {
        vm.prank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");

        vm.prank(pauser);
        certificateContract.pause();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        certificateContract.mintCertificate(user1, 1, "ipfs://QmHash");
    }

    function test_AddCourseBlockedWhenPaused() public {
        vm.prank(pauser);
        certificateContract.pause();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
    }
}

// ============================================================
//  UpdateAdminContract
// ============================================================

contract LearnWayCertificateTest_UpdateAdminContract is BaseTest {
    event AdminContractUpdated(address indexed newAdminContract, bool status);

    // --- Access Control ---

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        certificateContract.updateAdminContract(address(1));
    }

    // --- Input Validation ---

    function test_RevertWhen_NewAddressIsZero() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        certificateContract.updateAdminContract(address(0));
    }

    // --- Happy Path / Effects ---

    function test_UpdatesAdminContract() public {
        // Deploy new admin
        LearnWayAdmin newAdminImpl = new LearnWayAdmin();
        ERC1967Proxy newAdminProxy = new ERC1967Proxy(address(newAdminImpl), bytes(""));
        LearnWayAdmin newAdmin = LearnWayAdmin(address(newAdminProxy));
        vm.prank(admin);
        newAdmin.initialize();

        vm.prank(admin);
        certificateContract.updateAdminContract(address(newAdmin));

        assertEq(address(certificateContract.adminContract()), address(newAdmin));
    }

    // --- Events ---

    function test_EmitsAdminContractUpdatedEvent() public {
        address newAdmin = address(0x1234);

        vm.expectEmit(true, false, false, true);
        emit AdminContractUpdated(newAdmin, true);

        vm.prank(admin);
        certificateContract.updateAdminContract(newAdmin);
    }
}

// ============================================================
//  UpgradeSafety
// ============================================================

contract LearnWayCertificateTest_UpgradeSafety is BaseTest {
    // --- Access Control ---

    function test_RevertWhen_NonAdminTriesToUpgrade() public {
        LearnWayCertificate newImpl = new LearnWayCertificate();

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        certificateContract.upgradeToAndCall(address(newImpl), bytes(""));
    }

    // --- Happy Path ---

    function test_AdminCanUpgrade() public {
        LearnWayCertificate newImpl = new LearnWayCertificate();

        vm.prank(admin);
        certificateContract.upgradeToAndCall(address(newImpl), bytes(""));
    }

    function test_StatePreservedAfterUpgrade() public {
        vm.startPrank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
        certificateContract.mintCertificate(user1, 1, "ipfs://QmHash");
        vm.stopPrank();

        LearnWayCertificate newImpl = new LearnWayCertificate();
        vm.prank(admin);
        certificateContract.upgradeToAndCall(address(newImpl), bytes(""));

        assertTrue(certificateContract.hasCertificate(user1, 1));
        assertTrue(certificateContract.courseExists(1));
        (string memory name, string memory instructor, bool active) = certificateContract.getCourseInfo(1);
        assertEq(name, "Blockchain 101");
        assertEq(instructor, "Dr. Mensah");
        assertTrue(active);

        (bool exists, uint256 tokenId,,) = certificateContract.getCertificate(user1, 1);
        assertTrue(exists);
        assertEq(certificateContract.ownerOf(tokenId), user1);
    }

    function test_StatePreservedAfterUpgradeToV2() public {
        vm.startPrank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
        certificateContract.mintCertificate(user1, 1, "ipfs://QmHash");
        vm.stopPrank();

        MockLearnWayCertificateV2 v2Impl = new MockLearnWayCertificateV2();
        vm.prank(admin);
        certificateContract.upgradeToAndCall(
            address(v2Impl),
            abi.encodeWithSelector(MockLearnWayCertificateV2.initializeV2.selector, 42)
        );

        assertTrue(certificateContract.hasCertificate(user1, 1));
        assertTrue(certificateContract.courseExists(1));
        (, uint256 tokenId,,) = certificateContract.getCertificate(user1, 1);
        assertEq(certificateContract.ownerOf(tokenId), user1);
        (string memory name, string memory instructor, bool active) = certificateContract.getCourseInfo(1);
        assertEq(name, "Blockchain 101");
        assertEq(instructor, "Dr. Mensah");
        assertTrue(active);

        MockLearnWayCertificateV2 v2Proxy = MockLearnWayCertificateV2(address(certificateContract));
        assertEq(v2Proxy.newV2Variable(), 42);
    }

    function test_RevertWhen_ReinitializingAfterUpgrade() public {
        MockLearnWayCertificateV2 v2Impl = new MockLearnWayCertificateV2();
        vm.prank(admin);
        certificateContract.upgradeToAndCall(
            address(v2Impl),
            abi.encodeWithSelector(MockLearnWayCertificateV2.initializeV2.selector, 42)
        );

        MockLearnWayCertificateV2 v2Proxy = MockLearnWayCertificateV2(address(certificateContract));
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        v2Proxy.initializeV2(99);
    }

    function test_RevertWhen_CallingOriginalInitializeAfterUpgrade() public {
        MockLearnWayCertificateV2 v2Impl = new MockLearnWayCertificateV2();
        vm.prank(admin);
        certificateContract.upgradeToAndCall(address(v2Impl), bytes(""));

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        certificateContract.initialize(address(adminContract));
    }

    // --- Edge Cases ---

    function test_RevertWhen_UpgradingToNonUUPSContract() public {
        MockNonUUPS nonUups = new MockNonUUPS();

        vm.prank(admin);
        vm.expectRevert();
        certificateContract.upgradeToAndCall(address(nonUups), bytes(""));
    }
}

// ============================================================
//  GetCourseInfo
// ============================================================

contract LearnWayCertificateTest_GetCourseInfo is BaseTest {
    function test_RevertWhen_CourseDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidCourseId()"));
        certificateContract.getCourseInfo(999);
    }

    function test_ReturnsCorrectCourseInfo() public {
        vm.prank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");

        (string memory name, string memory instructor, bool active) = certificateContract.getCourseInfo(1);
        assertEq(name, "Blockchain 101");
        assertEq(instructor, "Dr. Mensah");
        assertTrue(active);
    }

    function test_ReflectsStatusUpdate() public {
        vm.startPrank(admin);
        certificateContract.addCourse(1, "Blockchain 101", "Dr. Mensah");
        certificateContract.updateCourseStatus(1, false);
        vm.stopPrank();

        (,, bool active) = certificateContract.getCourseInfo(1);
        assertFalse(active);
    }
}
