// SPDX-License-Identifier: MIT

/*

[ A G I J O B M A N A G E R  ( A G I J O B S  N F T )  T E R M S  A N D  C O N D I T I O N S ]

Published by: ALPHA.AGI.ETH
Approval Authority: ALPHA.AGI.ETH
Office of Primary Responsibility: ALPHA.AGI.ETH
Effective Date: The earlier of (i) your first interaction with the AGIJobManager smart contract on any chain, or (ii) the date you access or use any interface that facilitates such interaction.
OVERRIDING AUTHORITY: AGI.ETH

These Terms and Conditions (the "Terms") govern your access to and use of the AGIJobManager smart contract system (the "Protocol"), including any associated ERC-721 tokens minted by the Protocol (the "AGIJobs NFTs"). By calling, signing, submitting, or otherwise authorizing any transaction that interacts with the Protocol (directly or via any front-end), you agree to be bound by these Terms.

If you do not agree, do not use the Protocol.

IMPORTANT: The Protocol is experimental software. Smart contracts can fail, behave unexpectedly, or be exploited. Interacting with the Protocol can result in the total loss of digital assets. You assume all risks.

1. Definitions

- "Protocol" / "AGIJobManager": The AGIJobManager smart contract(s) implementing job posting, assignment, escrow, bonds, validation, disputes, and settlement.
- "$AGIALPHA": The ERC-20 token used by the Protocol for job payouts, validator rewards, agent/validator/dispute bonds, and any protocol-retained amounts.
- "Employer": Any person or entity that posts a Job and escrows a payout in $AGIALPHA.
- "Agent": Any person or entity that applies for, performs, and requests completion of a Job.
- "Validator": Any person or entity that votes to approve or disapprove a Job completion request under the Protocol rules, posting any required validator bond.
- "Moderator": An address designated by the Protocol owner with permission to resolve disputes through the Protocol's dispute-resolution functions.
- "Owner": The address holding administrative permissions in the Protocol (e.g., pausing, parameter updates, allowlist/blacklist management, moderator management, delisting unassigned jobs, and withdrawing certain withdrawable balances as permitted by the code).
- "Job": A work request defined by an on-chain job id plus off-chain/on-chain references (e.g., jobSpecURI, details, and later jobCompletionURI).
- "Job Spec URI": A URI describing the Job requested by the Employer.
- "Job Completion URI": A URI submitted by the Agent describing or containing the completion deliverable(s).
- "Escrow": The $AGIALPHA amount deposited by the Employer as the Job payout and held by the Protocol until settlement according to code.
- "Bonds": Any $AGIALPHA amounts posted as Agent bonds, Validator bonds, or Dispute bonds per the Protocol.
- "Settlement": The Protocol's distribution of escrowed payout and bonds according to the on-chain rules.
- "User Content": Any Job Spec URI, Job Completion URI, details, or any referenced content (including IPFS/HTTP content) supplied by users.

2. Nature of the Protocol; No Intermediary; Code Controls

1) Self-executing software. The Protocol is a set of smart contracts that execute transactions according to on-chain code. Outcomes (assignment, settlement, dispute states, reward allocation, slashing, etc.) are determined by the code and blockchain conditions.
2) No employment agency / marketplace operator role. The Protocol is not an employer, employment agency, staffing firm, contractor, broker, payment processor, escrow agent, fiduciary, or financial institution.
3) No party to user agreements. Any agreement regarding work scope, quality standards, deliverables, deadlines, confidentiality, IP ownership, compliance obligations, and payment terms exists only between the Employer and the Agent (and, if applicable, between either of them and any Validator). The Protocol is not a party to those agreements and has no obligations under them.
4) Code prevails. If these Terms conflict with the deployed code, the code prevails for on-chain behavior. These Terms allocate risk and responsibilities and govern off-chain expectations to the maximum extent permitted.

3. Eligibility; Sanctions; Legal Compliance (User Responsibility)

You represent, warrant, and covenant that:

- You have the legal capacity and authority to enter into these Terms.
- Your use of the Protocol is compliant with all applicable laws and regulations (present and future), including (without limitation) labor and employment laws, tax laws, consumer protection laws, IP laws, data protection laws, anti-bribery laws, export controls, and sanctions.
- You are not located in, organized under, or ordinarily resident in any jurisdiction where use of the Protocol would be unlawful.
- You are not subject to sanctions or on any restricted party lists, and you will not use the Protocol to transact with sanctioned parties or prohibited jurisdictions.

All compliance obligations are solely yours (Employer/Agent/Validator, as applicable). The Protocol does not perform KYC/AML checks and does not provide compliance advice or compliance services.

4. Roles and Exclusive Responsibilities

4.1 Employer Responsibilities (Exclusive)
The Employer is solely and exclusively responsible for:

- The legality, accuracy, and completeness of the Job description, Job Spec URI, details, and any referenced content.
- Ensuring the Job does not solicit or require unlawful acts, regulated acts without permits, infringement, malware, fraud, or rights violations.
- Determining whether a Job creates (or could be interpreted as creating) an employment relationship, and satisfying all obligations associated with such classification, including payroll, withholding, insurance, benefits, reporting, and worker protections.
- All tax obligations relating to posting the Job, escrowing $AGIALPHA, receiving any refunds, or any other token transfers.
- Any off-chain contracting, NDAs, IP assignments/licenses, confidentiality terms, acceptance criteria, warranties, or service levels for the Job.

4.2 Agent Responsibilities (Exclusive)
The Agent is solely and exclusively responsible for:

- Performing the Job in accordance with any off-chain agreement with the Employer.
- Ensuring all deliverables and the Job Completion URI content are lawful and do not violate third-party rights.
- All tax obligations relating to receiving $AGIALPHA payments, posting or forfeiting Agent bonds, or receiving any additional settlement amounts.
- Maintaining operational security of wallets, private keys, endpoints, and any systems used to perform Jobs.
- Understanding that Agent bonds may be forfeited under certain settlement paths per the code.

4.3 Validator Responsibilities (Exclusive)
Each Validator is solely and exclusively responsible for:

- Performing independent diligence before approving/disapproving completion, and voting honestly according to their own judgment and any standards they adopt or communicate.
- All consequences of their votes, including the possibility of slashing or reduced returns per the Protocol rules.
- All tax obligations relating to validator rewards, bond returns, slashing outcomes, and any other transfers.
- Compliance with all applicable laws (including any professional, licensing, or regulatory obligations that might apply to their validation activity).
- Avoiding bribery, collusion, or manipulation; recognizing that the Protocol's incentives may not prevent manipulation and that participation is at their own risk.

4.4 No Reliance on Validators, Moderators, or Owner

- Employers and Agents acknowledge that Validator participation may be insufficient, adversarial, mistaken, or absent.
- Moderators (where enabled) may act at their discretion, may be unavailable, and owe no duty to any user.
- The Owner may pause or restrict functions per the code and owes no duty to keep the Protocol available or to resolve disputes.

5. Job Lifecycle and Core Mechanics (Disclosure)

This section summarizes expected mechanics; the deployed code controls.

5.1 Posting a Job (Employer)

- To post a Job, the Employer escrows the full payout amount in $AGIALPHA into the Protocol.
- The Employer provides a Job Spec URI and optional details.
- Jobs may have maximum payout and duration limits set by the Protocol.

5.2 Applying / Assignment (Agent)

- A Job may be assigned to the first eligible Agent who successfully applies under the Protocol rules.
- Eligibility may depend on authorization mechanisms (e.g., allowlists, Merkle proofs, or ENS-based authorization).
- The Protocol may require an Agent bond (computed by code) to be posted at application/assignment time.
- The Agent's payout percentage may be determined by the Agent's holdings of specific NFT types configured in the Protocol and snapshotted at assignment time.

5.3 Completion Request (Agent)

- The Agent requests completion by submitting a Job Completion URI within the permitted time windows enforced by the Protocol.
- The Protocol may enforce review periods and timeouts.

5.4 Validation Voting (Validators)

- Authorized Validators may approve or disapprove during the completion review window.
- Validator voting may require posting a Validator bond per vote (computed by code).
- Validator votes can trigger:
  - Approval threshold reached (with a subsequent challenge window before settlement), or
  - Disapproval threshold reached, which may put the Job into dispute.

5.5 Finalization / Settlement (Anyone may be able to call)

- After the applicable review/challenge windows, settlement can occur according to the Protocol logic, including outcomes where:
  - The Agent wins (payout to Agent, validator rewards distributed, remainder retained by protocol), or
  - The Employer wins (refund to Employer, validator settlement, possible agent bond forfeiture), or
  - A dispute is forced due to insufficient participation or ties.

5.6 Expiration

- If conditions in the code are met (e.g., time elapsed without completion request), a Job may be expired, which can trigger refund mechanics and bond settlement.

5.7 Cancellation / Delisting

- An Employer may be able to cancel an unassigned Job (per code).
- The Owner may delist/cancel unassigned Jobs (per code).
- Users acknowledge there is no obligation to keep a Job listed or available.

6. Disputes; Moderation; No Duty to Resolve

1) Dispute initiation. A dispute may be initiated by an Employer or Agent (and/or may be triggered by validator disapproval thresholds) as permitted by the code. Disputes may require a Dispute bond in $AGIALPHA.
2) Moderator resolution. Where enabled, Moderators may resolve disputes using the Protocol's dispute code mechanism (e.g., settle in favor of Agent or Employer).
3) No obligation; no SLA. The Protocol, Owner, and Moderators have no obligation to resolve disputes within any timeframe (or at all), except as the code permits. Any reliance on moderator action is at user risk.
4) Off-chain disputes remain off-chain. The Protocol cannot adjudicate legal questions (fraud, IP infringement, breach of contract, misrepresentation, employment classification, etc.). Those issues are solely between users and must be handled off-chain.

7. Protocol Economics; Fees; Retained Remainder Disclosure

1) Validator reward budget. The Protocol may allocate a portion of the Job payout as a validator reward budget (as snapshotted per job) for distribution to participating Validators, subject to code rules.
2) Bond returns and slashing. Validator bonds may be returned in full, partially slashed, or redistributed depending on whether a Validator ends up on the correct side of the final outcome, as defined by the code.
3) Protocol-retained remainder (platform revenue). On certain settlement paths (including Agent-win), the Protocol may retain the remainder of the Job payout after Agent and Validator allocations. This remainder may become withdrawable by the Owner under conditions specified in the code (e.g., when paused and when not backing active escrows/bonds).
4) No refunds from the Protocol. Token movements are governed by the smart contract; there is no guarantee of reversal, refunds, or discretionary recovery.
5) Gas fees. Users pay their own gas/transaction fees and accept the risk of network congestion, failed transactions, MEV, reorgs, and other chain-level issues.

8. Taxes, Withholding, Reporting (Exclusive User Responsibility)

The Employer, Agent, and each Validator are exclusively responsible for:

- Determining and paying any and all taxes (income, payroll, self-employment, VAT/GST/sales tax, withholding, capital gains, information reporting, etc.) arising from:
  - Job payouts, validator rewards, protocol distributions, refunds;
  - Posting, returning, or forfeiting bonds;
  - Token price volatility and taxable events in their jurisdiction.
- Maintaining records and issuing any required invoices, receipts, and tax forms.
- Handling any withholding obligations, if applicable.

The Protocol does not provide tax advice, does not withhold taxes, and does not issue tax forms.

9. No Employment Relationship; Independent Contractors Only

1) No employment relationship created by the Protocol. Nothing in the Protocol or these Terms creates an employment, partnership, joint venture, agency, fiduciary, or franchise relationship between:
   - The Protocol (or its publishers/maintainers/Owner/Moderators) and any user; or
   - Any Employer and any Agent, unless they separately create such a relationship off-chain.
2) Employer classification duty. The Employer is solely responsible for worker classification and compliance with all related obligations.
3) No benefits. The Protocol does not provide benefits, insurance, or protections to any user.

10. User Content; Intellectual Property; Confidentiality

1) User Content is user responsibility. Employers and Agents (and any Validators who publish content) are solely responsible for any User Content they submit or reference, including legality, accuracy, and IP permissions.
2) No IP transfer by default. The Protocol and AGIJobs NFTs do not automatically transfer or license intellectual property rights. Any IP transfer/license must be agreed off-chain between the relevant parties.
3) Public nature of blockchains. On-chain actions are public. URIs and referenced content may be publicly accessible. Do not submit sensitive personal data or confidential information unless you accept that risk and have the rights to do so.

11. Prohibited Uses

You may not use the Protocol to:

- Violate any law or regulation (including sanctions, export controls, labor laws, tax laws, or consumer protection laws).
- Post or perform Jobs involving fraud, theft, violence, doxxing, harassment, malware, exploitation, or rights infringement.
- Circumvent authorization/eligibility mechanisms or use compromised wallets/keys.
- Engage in bribery, collusion, or manipulation of Validator voting or dispute outcomes.

The Owner may maintain blacklists or otherwise restrict participation as permitted by the code. Such actions are discretionary and create no duty.

12. Assumption of Risk (Smart Contract and Crypto Risks)

You acknowledge and accept, without limitation, the risks of:

- Smart contract bugs, exploits, reentrancy, logic errors, and unforeseen interactions.
- Chain congestion, MEV/front-running, reorgs, downtime, and client bugs.
- Token volatility, illiquidity, and loss of value of $AGIALPHA.
- Validator non-participation, collusion, bribery, or incorrect outcomes.
- Irreversible transactions and the impossibility of guaranteed recovery.
- Loss of private keys or compromised wallets.

13. Disclaimers; No Warranties

To the maximum extent permitted by law:

- The Protocol and any related materials are provided "AS IS" and "AS AVAILABLE".
- No warranties are provided, including warranties of merchantability, fitness for a particular purpose, non-infringement, accuracy, security, uptime, or that any particular outcome will be achieved.
- No statement in documentation, interfaces, community channels, or elsewhere creates any warranty or duty.

14. Limitation of Liability

To the maximum extent permitted by law:

- In no event shall the Protocol, its publishers, maintainers, contributors, Owner, Moderators, or any related persons be liable for any indirect, incidental, special, consequential, exemplary, or punitive damages, or any loss of profits, revenue, data, goodwill, or digital assets, arising out of or related to your use of the Protocol.
- Any liability that cannot be excluded is limited to the minimum amount permitted by law.

All liability for Jobs, deliverables, validation activities, disputes, taxes, and compliance rests exclusively with Employers, Agents, and Validators.

15. Indemnification

To the maximum extent permitted by law, you agree to defend, indemnify, and hold harmless the Protocol, its publishers, maintainers, contributors, Owner, Moderators, and related persons from and against any and all claims, demands, actions, damages, losses, liabilities, costs, and expenses (including reasonable attorneys' fees) arising out of or related to:

- Your use of the Protocol;
- Any Job you post, perform, validate, approve/disapprove, dispute, or otherwise participate in;
- Any User Content you submit or reference;
- Your breach of these Terms; or
- Your violation of any law or third-party rights.

16. Governing Law; Forum; User-to-User Disputes

1) User-to-user disputes. Any dispute between an Employer, Agent, and/or Validator is strictly between those parties. The Protocol (and its publishers/maintainers/Owner/Moderators) is not a party and shall not be named as such to the extent permitted.
2) Governing law for user-to-user disputes. User-to-user disputes shall be governed by the laws applicable to those users and their off-chain agreement(s), if any.
3) Protocol not subject to jurisdiction. You agree that you will not seek to impose jurisdiction over the Protocol as a party to any user-to-user dispute, to the maximum extent permitted by law.

17. Changes to Terms; Continued Use

- The publisher may publish updated Terms from time to time (including at a canonical URL or IPFS link).
- Continued use of the Protocol after publication of updated Terms constitutes acceptance of those updated Terms to the extent permitted by law.
- Historic on-chain behavior remains governed by the deployed code and the blockchain state.

18. Severability; Entire Agreement; No Waiver

- Severability: If any provision is held invalid or unenforceable, the remaining provisions remain in full force.
- Entire Agreement: These Terms constitute the entire agreement between you and the publisher regarding your use of the Protocol (without affecting any separate agreements between users).
- No Waiver: Failure to enforce any provision is not a waiver.

Regulatory Compliance & Legal Disclosures (Token and Program)

1) Utility Token Only: $AGIALPHA is intended as a utility token used within an experimental system (including paying for protocol-defined interactions, payouts, and bonds). It is not intended to represent equity, ownership, profit-sharing, or voting rights in any entity.
2) No Expectation of Profit: Any expectation of profit, yield, or return is unjustified.
3) No Guarantee of Value: No party guarantees any value, price stability, or liquidity of $AGIALPHA.
4) Non-Refundable Token Purchases: Where applicable, token acquisitions are final and non-refundable, subject to mandatory consumer laws that cannot be waived.
5) User Compliance Responsibility: Users are solely responsible for ensuring acquisition, holding, and use of $AGIALPHA complies with all laws in their jurisdiction, including securities, commodities, consumer, tax, and AML-related obligations that may apply to them.

Research Program Notice; No Warranty

THIS IS PART OF AN ASPIRATIONAL RESEARCH PROGRAM WITH AN AMBITIOUS RESEARCH AGENDA. ANY EXPECTATION OF PROFIT OR RETURN IS UNJUSTIFIED. POSSESSION OF $AGIALPHA DOES NOT SIGNIFY OR ESTABLISH ANY ENTITLEMENT OR INTEREST, SHARE OR EQUITY, BOND OR ANALOGOUS ENTITLEMENT, OR ANY RIGHT TO OBTAIN ANY FUTURE INCOME. MATERIALS PROVIDED IN THIS SYSTEM ARE WITHOUT WARRANTY OF ANY KIND AND DO NOT CONSTITUTE ENDORSEMENT AND CAN BE MODIFIED AT ANY TIME. BY USING THE PRESENT SYSTEM, YOU AGREE TO THE $AGIALPHA TERMS AND CONDITIONS. ANY USE OF THIS SYSTEM, OR ANY OF THE INFORMATION CONTAINED HEREIN, FOR OTHER THAN THE PURPOSE FOR WHICH IT WAS DEVELOPED, IS EXPRESSLY PROHIBITED, EXCEPT AS AGI.ETH MAY OTHERWISE AGREE TO IN WRITING OFFICIALLY.

OVERRIDING AUTHORITY: AGI.ETH

By interacting with the AGIJobManager smart contract, you acknowledge that you have read, understood, and agree to be bound by these Terms.

--------------------------------------------------------------------------------

[ R E G U L A T O R Y  C O M P L I A N C E  &  L E G A L  D I S C L O S U R E S ]

Published by: ALPHA.AGI.ETH

Approval Authority: ALPHA.AGI.ETH

Office of Primary Responsibility: ALPHA.AGI.ETH

Initial Terms & Conditions

The Emergence of an AGI-Powered Alpha Agent.

Ticker ($): AGIALPHA

Rooted in the publicly disclosed 2017 "Multi-Agent AI DAO" prior art, the AGI ALPHA AGENT utilizes $AGIALPHA tokens purely as utility tokens—no equity, no profit-sharing—to grant users prepaid access to the AGI ALPHA AGENT’s capabilities. By structuring $AGIALPHA as an advance payment mechanism for leveraging ALPHA.AGENT.AGI.Eth’s AI-driven services, holders likely avoid securities classification complexities. By purchasing these tokens, you gain usage credits for future AI services from the AGI ALPHA AGENT. Instead of representing ownership or investment rights, these tokens simply secure the right to interact with and benefit from the AGI ALPHA AGENT’s intelligence and outputs. This model delivers a straightforward, compliance-friendly approach to accessing cutting-edge AI functionalities, ensuring a seamless, equity-free experience for all participants.

1. Token Usage: $AGIALPHA tokens are strictly utility tokens—no equity, no profit-sharing—intended for the purchase of products/services by the AGI ALPHA AGENT (ALPHA.AGENT.AGI.Eth). They are not intended for investment or speculative purposes.

2. Non-Refundable: Purchases of $AGIALPHA tokens are final and non-refundable.

3. No Guarantee of Value: The issuer does not guarantee any specific value of the $AGIALPHA token in relation to fiat currencies or other cryptocurrencies.

4. Regulatory Compliance: It is the user’s responsibility to ensure that the purchase and use of $AGIALPHA tokens comply with all applicable laws and regulations.

5. User Responsibility: Users are responsible for complying with the laws in their own jurisdiction regarding the purchase and use of $AGIALPHA tokens.

OVERRIDING AUTHORITY: AGI.Eth

$AGIALPHA is experimental and part of an ambitious research agenda. Any expectation of profit is unjustified.

Materials provided (including $AGIALPHA) are without warranty. By using $AGIALPHA, you agree to the $AGIALPHA Terms and Conditions.

Changes to Terms: The issuer may revise these terms at any time, subject to regulatory compliance. Current Terms & Conditions: https://agialphaagent.com/.

THIS IS PART OF AN ASPIRATIONAL RESEARCH PROGRAM WITH AN AMBITIOUS RESEARCH AGENDA. ANY EXPECTATION OF PROFIT OR RETURN IS UNJUSTIFIED. POSSESSION OF $AGIALPHA DOES NOT SIGNIFY OR ESTABLISH ANY ENTITLEMENT OR INTEREST, SHARE OR EQUITY, BOND OR ANALOGOUS ENTITLEMENT, OR ANY RIGHT TO OBTAIN ANY FUTURE INCOME. MATERIALS PROVIDED IN THIS SYSTEM ARE WITHOUT WARRANTY OF ANY KIND AND DO NOT CONSTITUTE ENDORSEMENT AND CAN BE MODIFIED AT ANY TIME. BY USING THE PRESENT SYSTEM, YOU AGREE TO THE $AGIALPHA TERMS AND CONDITIONS. ANY USE OF THIS SYSTEM, OR ANY OF THE INFORMATION CONTAINED HEREIN, FOR OTHER THAN THE PURPOSE FOR WHICH IT WAS DEVELOPED, IS EXPRESSLY PROHIBITED, EXCEPT AS AGI.ETH MAY OTHERWISE AGREE TO IN WRITING OFFICIALLY.

OVERRIDING AUTHORITY: AGI.ETH

*/

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./utils/UriUtils.sol";
import "./utils/BondMath.sol";
import "./utils/ReputationMath.sol";
import "./utils/ENSOwnership.sol";
import "./periphery/AGIJobCompletionNFT.sol";

interface ENSPrime {
    function resolver(bytes32 node) external view returns (address);
}

interface NameWrapperPrime {
    function ownerOf(uint256 id) external view returns (address);
}

contract AGIJobManagerPrime is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    enum IntakeMode {
        OpenFirstCome,
        SelectedAgentOnly,
        PerJobMerkleRoot
    }

    error NotModerator();
    error NotAuthorized();
    error NotDiscovery();
    error Blacklisted();
    error InvalidParameters();
    error InvalidState();
    error JobNotFound();
    error SettlementPaused();
    error InvalidValidatorThresholds();
    error IneligibleAgentPayout();
    error InsufficientWithdrawableBalance();
    error InsolventEscrowBalance();
    error RenounceOwnershipDisabled();
    error DisputeAlreadyOpen();

    uint256 public constant MAX_VALIDATORS_PER_JOB = 50;
    uint256 public constant MAX_AGI_TYPES = 32;
    uint256 internal constant MAX_REVIEW_PERIOD = 365 days;
    uint256 internal constant DISPUTE_BOND_BPS = 50;
    uint256 internal constant DISPUTE_BOND_MIN = 1e18;
    uint256 internal constant DISPUTE_BOND_MAX = 200e18;
    uint256 internal constant MAX_URI_BYTES = 2048;
    uint8 internal constant ENS_HOOK_CREATE = 1;
    uint8 internal constant ENS_HOOK_ASSIGN = 2;
    uint8 internal constant ENS_HOOK_COMPLETION = 3;
    uint8 internal constant ENS_HOOK_REVOKE = 4;
    uint8 internal constant ENS_HOOK_LOCK = 5;
    uint256 internal constant ENS_HOOK_GAS_LIMIT = 500_000;

    IERC20 public agiToken;
    address public discoveryModule;
    string public baseIpfsUrl;

    uint256 public requiredValidatorApprovals = 3;
    uint256 public requiredValidatorDisapprovals = 3;
    uint256 public voteQuorum = 3;

    uint256 public premiumReputationThreshold = 10_000;
    uint256 public validationRewardPercentage = 8;
    uint256 public maxJobPayout = 88_888_888e18;
    uint256 public jobDurationLimit = 10_000_000;

    uint256 public completionReviewPeriod = 7 days;
    uint256 public disputeReviewPeriod = 14 days;
    uint256 public challengePeriodAfterApproval = 1 days;

    bool public settlementPaused;
    uint64 public pauseStartedAt;
    uint64 public pausedSecondsAccumulated;

    uint256 public validatorBondBps = 1500;
    uint256 public validatorBondMin = 10e18;
    uint256 public validatorBondMax = 88_888_888e18;
    uint256 public validatorSlashBps = 8000;

    uint256 public agentBond = 1e18;
    uint256 public agentBondBps = 500;
    uint256 public agentBondMax = 88_888_888e18;

    uint256 public lockedEscrow;
    uint256 public lockedAgentBonds;
    uint256 public lockedValidatorBonds;
    uint256 public lockedDisputeBonds;

    uint256 public maxActiveJobsPerAgent = 3;

    bytes32 public clubRootNode;
    bytes32 public alphaClubRootNode;
    bytes32 public agentRootNode;
    bytes32 public alphaAgentRootNode;
    bytes32 public validatorMerkleRoot;
    bytes32 public agentMerkleRoot;

    ENSPrime public ens;
    NameWrapperPrime public nameWrapper;
    address public ensJobPages;

    struct Job {
        address employer;
        string jobSpecURI;
        string jobCompletionURI;
        string checkpointURI;

        uint256 payout;
        uint256 duration;

        IntakeMode intakeMode;
        bytes32 perJobAgentRoot;

        address selectedAgent;
        uint64 selectionExpiresAt;

        uint64 checkpointWindow;
        uint64 checkpointDeadline;
        bool checkpointSubmitted;

        address assignedAgent;
        uint64 assignedAt;

        bool completed;
        bool completionRequested;
        bool disputed;
        bool expired;
        bool escrowReleased;
        bool validatorApproved;

        uint32 validatorApprovals;
        uint32 validatorDisapprovals;

        uint64 completionRequestedAt;
        uint64 disputedAt;
        uint64 validatorApprovedAt;
        uint64 completionReviewPeriodSnapshot;
        uint64 disputeReviewPeriodSnapshot;
        uint64 challengePeriodAfterApprovalSnapshot;
        uint64 pauseSecondsBaseline;

        uint256 voteQuorumSnapshot;
        uint256 requiredValidatorApprovalsSnapshot;
        uint256 requiredValidatorDisapprovalsSnapshot;
        uint256 validatorSlashBpsSnapshot;

        address disputeInitiator;
        uint256 disputeBondAmount;
        uint256 validatorBondAmount;
        uint256 agentBondAmount;

        uint8 agentPayoutPct;
        uint8 validatorRewardPctSnapshot;

        mapping(address => bool) approvals;
        mapping(address => bool) disapprovals;
        address[] validators;
    }

    struct AGIType {
        address nftAddress;
        uint256 payoutPercentage;
    }

    struct AgentStats {
        uint64 completedJobs;
        uint64 failedJobs;
        uint64 disputeLosses;
        uint64 expiredJobs;
        uint128 successVolume;
        uint128 failVolume;
        uint64 lastOutcomeAt;
    }

    uint256 public nextJobId;

    mapping(uint256 => Job) internal jobs;
    mapping(address => uint256) public reputation;
    mapping(address => AgentStats) public agentStats;

    mapping(address => bool) public moderators;
    mapping(address => bool) public additionalValidators;
    mapping(address => bool) public additionalAgents;
    mapping(address => bool) public blacklistedAgents;
    mapping(address => bool) public blacklistedValidators;
    mapping(address => uint256) public activeJobsByAgent;

    AGIType[] public agiTypes;
    AGIJobCompletionNFT public immutable completionNFT;

    event JobCreated(
        uint256 indexed jobId,
        address indexed employer,
        uint256 payout,
        uint256 duration,
        string jobSpecURI,
        IntakeMode intakeMode,
        bytes32 indexed perJobAgentRoot,
        string details
    );
    event JobApplied(uint256 indexed jobId, address indexed agent);
    event CheckpointSubmitted(uint256 indexed jobId, address indexed agent, string checkpointURI);
    event CheckpointFailed(uint256 indexed jobId, address indexed employer, address indexed agent);
    event JobCompletionRequested(uint256 indexed jobId, address indexed agent, string jobCompletionURI);
    event JobValidated(uint256 indexed jobId, address indexed validator);
    event JobDisapproved(uint256 indexed jobId, address indexed validator);
    event JobDisputed(uint256 indexed jobId, address indexed disputant);
    event JobCompleted(uint256 indexed jobId, address indexed agent, uint256 indexed reputationPoints);
    event JobEmployerRefunded(uint256 indexed jobId, address indexed employer, address indexed agent, uint256 refund);
    event JobExpired(uint256 indexed jobId, address indexed employer, address indexed agent, uint256 payout);
    event JobCancelled(uint256 indexed jobId);
    event DisputeResolvedWithCode(uint256 indexed jobId, address indexed resolver, uint8 indexed code, string reason);
    event NFTIssued(uint256 indexed tokenId, address indexed employer, string tokenURI);

    event ReputationUpdated(address indexed user, uint256 newReputation);
    event DiscoveryModuleUpdated(address indexed oldModule, address indexed newModule);
    event SelectedAgentDesignated(
        uint256 indexed jobId,
        address indexed selectedAgent,
        uint64 selectionExpiresAt,
        uint64 checkpointWindow
    );
    event JobAgentRootUpdated(uint256 indexed jobId, bytes32 indexed perJobAgentRoot, uint64 selectionExpiresAt);

    event AgentBlacklisted(address indexed agent, bool status);
    event ValidatorBlacklisted(address indexed validator, bool status);
    event CompletionReviewPeriodUpdated(uint256 oldValue, uint256 newValue);
    event DisputeReviewPeriodUpdated(uint256 oldValue, uint256 newValue);
    event ChallengePeriodAfterApprovalUpdated(uint256 oldValue, uint256 newValue);
    event ValidatorBondParamsUpdated(uint256 bps, uint256 min, uint256 max);
    event AgentBondParamsUpdated(uint256 bps, uint256 min, uint256 max);
    event ValidatorSlashBpsUpdated(uint256 oldValue, uint256 newValue);
    event SettlementPauseSet(address indexed setter, bool paused);
    event AGITypeUpdated(address indexed nftAddress, uint256 indexed payoutPercentage);
    event AGIWithdrawn(address indexed to, uint256 amount, uint256 remainingWithdrawable);

    modifier onlyModerator() {
        if (!moderators[msg.sender]) revert NotModerator();
        _;
    }

    modifier onlyDiscoveryOrOwner() {
        if (msg.sender != discoveryModule && msg.sender != owner()) revert NotDiscovery();
        _;
    }

    modifier whenSettlementNotPaused() {
        if (settlementPaused) revert SettlementPaused();
        _;
    }


    constructor(
        address agiTokenAddress,
        string memory baseIpfs,
        address ensAddress,
        address nameWrapperAddress,
        bytes32[4] memory rootNodes,
        bytes32[2] memory merkleRoots
    ) {
        if (agiTokenAddress == address(0) || agiTokenAddress.code.length == 0) revert InvalidParameters();

        agiToken = IERC20(agiTokenAddress);
        completionNFT = new AGIJobCompletionNFT(address(this));
        baseIpfsUrl = baseIpfs;

        ens = ENSPrime(ensAddress);
        nameWrapper = NameWrapperPrime(nameWrapperAddress);

        clubRootNode = rootNodes[0];
        agentRootNode = rootNodes[1];
        alphaClubRootNode = rootNodes[2];
        alphaAgentRootNode = rootNodes[3];
        validatorMerkleRoot = merkleRoots[0];
        agentMerkleRoot = merkleRoots[1];

        _validateValidatorThresholds(requiredValidatorApprovals, requiredValidatorDisapprovals);
    }

    function pause() external onlyOwner {
        bool wasClockPaused = _isClockPaused();
        _pause();
        _handlePauseClockTransition(wasClockPaused, _isClockPaused());
    }

    function unpause() external onlyOwner {
        bool wasClockPaused = _isClockPaused();
        _unpause();
        _handlePauseClockTransition(wasClockPaused, _isClockPaused());
    }

    function setSettlementPaused(bool paused_) external onlyOwner {
        bool wasClockPaused = _isClockPaused();
        settlementPaused = paused_;
        _handlePauseClockTransition(wasClockPaused, _isClockPaused());
        emit SettlementPauseSet(msg.sender, paused_);
    }

    function setDiscoveryModule(address module) external onlyOwner {
        if (module == address(0) || module.code.length == 0) revert InvalidParameters();
        address old = discoveryModule;
        discoveryModule = module;
        emit DiscoveryModuleUpdated(old, module);
    }

    function setEnsJobPages(address target) external onlyOwner {
        if (target != address(0) && target.code.length == 0) revert InvalidParameters();
        ensJobPages = target;
    }

    function renounceOwnership() public view override onlyOwner {
        revert RenounceOwnershipDisabled();
    }


    function addModerator(address a) external onlyOwner { moderators[a] = true; }
    function removeModerator(address a) external onlyOwner { moderators[a] = false; }

    function addAdditionalAgent(address a) external onlyOwner { additionalAgents[a] = true; }
    function removeAdditionalAgent(address a) external onlyOwner { additionalAgents[a] = false; }

    function addAdditionalValidator(address a) external onlyOwner { additionalValidators[a] = true; }
    function removeAdditionalValidator(address a) external onlyOwner { additionalValidators[a] = false; }

    function blacklistAgent(address a, bool status) external onlyOwner {
        blacklistedAgents[a] = status;
        emit AgentBlacklisted(a, status);
    }

    function blacklistValidator(address a, bool status) external onlyOwner {
        blacklistedValidators[a] = status;
        emit ValidatorBlacklisted(a, status);
    }

    function updateMerkleRoots(bytes32 validatorRoot, bytes32 agentRoot) external onlyOwner {
        validatorMerkleRoot = validatorRoot;
        agentMerkleRoot = agentRoot;
    }

    function updateRootNodes(
        bytes32 _clubRootNode,
        bytes32 _agentRootNode,
        bytes32 _alphaClubRootNode,
        bytes32 _alphaAgentRootNode
    ) external onlyOwner {
        if ((lockedEscrow | lockedAgentBonds | lockedValidatorBonds | lockedDisputeBonds) != 0) revert InvalidState();
        clubRootNode = _clubRootNode;
        agentRootNode = _agentRootNode;
        alphaClubRootNode = _alphaClubRootNode;
        alphaAgentRootNode = _alphaAgentRootNode;
    }

    function setVoteQuorum(uint256 q) external onlyOwner {
        if (q == 0 || q > MAX_VALIDATORS_PER_JOB) revert InvalidParameters();
        voteQuorum = q;
    }

    function setRequiredValidatorApprovals(uint256 v) external onlyOwner {
        _validateValidatorThresholds(v, requiredValidatorDisapprovals);
        requiredValidatorApprovals = v;
    }

    function setRequiredValidatorDisapprovals(uint256 v) external onlyOwner {
        _validateValidatorThresholds(requiredValidatorApprovals, v);
        requiredValidatorDisapprovals = v;
    }

    function setPremiumReputationThreshold(uint256 v) external onlyOwner {
        premiumReputationThreshold = v;
    }

    function setValidationRewardPercentage(uint256 v) external onlyOwner {
        if (v == 0 || v > 100) revert InvalidParameters();
        validationRewardPercentage = v;
    }

    function setCompletionReviewPeriod(uint256 v) external onlyOwner {
        if (v == 0 || v > MAX_REVIEW_PERIOD) revert InvalidParameters();
        uint256 old = completionReviewPeriod;
        completionReviewPeriod = v;
        emit CompletionReviewPeriodUpdated(old, v);
    }

    function setDisputeReviewPeriod(uint256 v) external onlyOwner {
        if (v == 0 || v > MAX_REVIEW_PERIOD) revert InvalidParameters();
        uint256 old = disputeReviewPeriod;
        disputeReviewPeriod = v;
        emit DisputeReviewPeriodUpdated(old, v);
    }

    function setChallengePeriodAfterApproval(uint256 v) external onlyOwner {
        if (v == 0 || v > MAX_REVIEW_PERIOD) revert InvalidParameters();
        uint256 old = challengePeriodAfterApproval;
        challengePeriodAfterApproval = v;
        emit ChallengePeriodAfterApprovalUpdated(old, v);
    }

    function setValidatorBondParams(uint256 bps, uint256 min, uint256 max) external onlyOwner {
        if (bps > 10_000 || min > max) revert InvalidParameters();
        validatorBondBps = bps;
        validatorBondMin = min;
        validatorBondMax = max;
        emit ValidatorBondParamsUpdated(bps, min, max);
    }

    function setAgentBondParams(uint256 bps, uint256 min, uint256 max) external onlyOwner {
        if (bps > 10_000 || min > max) revert InvalidParameters();
        agentBondBps = bps;
        agentBond = min;
        agentBondMax = max;
        emit AgentBondParamsUpdated(bps, min, max);
    }

    function setValidatorSlashBps(uint256 bps) external onlyOwner {
        if (bps > 10_000) revert InvalidParameters();
        uint256 old = validatorSlashBps;
        validatorSlashBps = bps;
        emit ValidatorSlashBpsUpdated(old, bps);
    }

    function createJob(
        string calldata jobSpecURI,
        uint256 payout,
        uint256 duration,
        string calldata details
    ) external returns (uint256) {
        return _createJob(msg.sender, jobSpecURI, payout, duration, details, IntakeMode.OpenFirstCome, bytes32(0));
    }

    function createConfiguredJob(
        string calldata jobSpecURI,
        uint256 payout,
        uint256 duration,
        string calldata details,
        IntakeMode intakeMode,
        bytes32 perJobAgentRoot
    ) external returns (uint256) {
        return _createJob(msg.sender, jobSpecURI, payout, duration, details, intakeMode, perJobAgentRoot);
    }

    function createConfiguredJobFor(
        address employer,
        string calldata jobSpecURI,
        uint256 payout,
        uint256 duration,
        string calldata details,
        uint8 intakeMode,
        bytes32 perJobAgentRoot
    ) external onlyDiscoveryOrOwner whenNotPaused whenSettlementNotPaused returns (uint256) {
        if (intakeMode > uint8(IntakeMode.PerJobMerkleRoot)) revert InvalidParameters();
        return _createJob(employer, jobSpecURI, payout, duration, details, IntakeMode(intakeMode), perJobAgentRoot);
    }

    function designateSelectedAgent(
        uint256 jobId,
        address selectedAgent,
        uint64 acceptanceWindow,
        uint64 checkpointWindow
    ) external onlyDiscoveryOrOwner whenNotPaused whenSettlementNotPaused {
        if (selectedAgent == address(0) || acceptanceWindow == 0) revert InvalidParameters();

        Job storage job = _job(jobId);
        if (job.intakeMode != IntakeMode.SelectedAgentOnly) revert InvalidState();
        if (job.assignedAgent != address(0) || job.completed || job.expired) revert InvalidState();
        if (job.selectionExpiresAt != 0 && _effectiveTimestamp(job) <= job.selectionExpiresAt) revert InvalidState();

        _resetPauseBaseline(job);
        job.selectedAgent = selectedAgent;
        job.selectionExpiresAt = uint64(block.timestamp + acceptanceWindow);
        job.checkpointWindow = checkpointWindow;

        emit SelectedAgentDesignated(jobId, selectedAgent, job.selectionExpiresAt, checkpointWindow);
    }

    function setPerJobAgentRoot(
        uint256 jobId,
        bytes32 root,
        uint64 applicationWindow
    ) external onlyDiscoveryOrOwner whenNotPaused whenSettlementNotPaused {
        if (root == bytes32(0) || applicationWindow == 0) revert InvalidParameters();

        Job storage job = _job(jobId);
        if (job.intakeMode != IntakeMode.PerJobMerkleRoot) revert InvalidState();
        if (job.assignedAgent != address(0) || job.completed || job.expired) revert InvalidState();

        _resetPauseBaseline(job);
        job.perJobAgentRoot = root;
        job.selectionExpiresAt = uint64(block.timestamp + applicationWindow);

        emit JobAgentRootUpdated(jobId, root, job.selectionExpiresAt);
    }

    function applyForJob(
        uint256 jobId,
        string calldata subdomain,
        bytes32[] calldata globalProof,
        bytes32[] calldata perJobProof
    ) external whenNotPaused whenSettlementNotPaused nonReentrant {
        Job storage job = _job(jobId);
        if (job.assignedAgent != address(0) || job.completed || job.expired) revert InvalidState();
        if (blacklistedAgents[msg.sender]) revert Blacklisted();
        if (activeJobsByAgent[msg.sender] >= maxActiveJobsPerAgent) revert InvalidState();

        if (!_isAuthorized(msg.sender, subdomain, globalProof, additionalAgents, agentMerkleRoot, agentRootNode, alphaAgentRootNode)) {
            revert NotAuthorized();
        }

        if (job.intakeMode == IntakeMode.OpenFirstCome) {
        } else if (job.intakeMode == IntakeMode.SelectedAgentOnly) {
            if (msg.sender != job.selectedAgent) revert NotAuthorized();
            if (_effectiveTimestamp(job) > job.selectionExpiresAt) revert InvalidState();
        } else {
            if (job.perJobAgentRoot == bytes32(0)) revert InvalidState();
            if (_effectiveTimestamp(job) > job.selectionExpiresAt) revert InvalidState();
            if (!MerkleProof.verify(perJobProof, job.perJobAgentRoot, keccak256(abi.encodePacked(msg.sender)))) {
                revert NotAuthorized();
            }
        }

        uint256 snapshotPct = getHighestPayoutPercentage(msg.sender);
        if (snapshotPct == 0) revert IneligibleAgentPayout();

        job.agentPayoutPct = uint8(snapshotPct);
        job.validatorRewardPctSnapshot = uint8(validationRewardPercentage);
        if (uint256(job.agentPayoutPct) + uint256(job.validatorRewardPctSnapshot) > 100) revert InvalidParameters();
        job.completionReviewPeriodSnapshot = uint64(completionReviewPeriod);
        job.disputeReviewPeriodSnapshot = uint64(disputeReviewPeriod);
        job.challengePeriodAfterApprovalSnapshot = uint64(challengePeriodAfterApproval);
        job.voteQuorumSnapshot = voteQuorum;
        job.requiredValidatorApprovalsSnapshot = requiredValidatorApprovals;
        job.requiredValidatorDisapprovalsSnapshot = requiredValidatorDisapprovals;
        job.validatorSlashBpsSnapshot = validatorSlashBps;

        uint256 bond = BondMath.computeAgentBond(
            job.payout,
            job.duration,
            agentBondBps,
            agentBond,
            agentBondMax,
            jobDurationLimit
        );

        if (bond > 0) {
            agiToken.safeTransferFrom(msg.sender, address(this), bond);
            lockedAgentBonds += bond;
        }

        job.agentBondAmount = bond;
        _resetPauseBaseline(job);
        job.assignedAgent = msg.sender;
        job.assignedAt = uint64(block.timestamp);

        if (job.checkpointWindow > 0) {
            job.checkpointDeadline = uint64(block.timestamp + job.checkpointWindow);
        }

        activeJobsByAgent[msg.sender] += 1;
        emit JobApplied(jobId, msg.sender);
        _callEnsJobPagesHook(ENS_HOOK_ASSIGN, jobId);
    }

    function submitCheckpoint(
        uint256 jobId,
        string calldata checkpointURI
    ) external whenSettlementNotPaused {
        Job storage job = _job(jobId);
        if (msg.sender != job.assignedAgent) revert NotAuthorized();
        if (job.completed || job.expired || job.completionRequested) revert InvalidState();
        if (job.checkpointWindow == 0 || job.checkpointDeadline == 0) revert InvalidState();
        if (_effectiveTimestamp(job) > job.checkpointDeadline) revert InvalidState();
        if (job.checkpointSubmitted) revert InvalidState();
        if (bytes(checkpointURI).length == 0 || bytes(checkpointURI).length > MAX_URI_BYTES) revert InvalidParameters();

        UriUtils.requireValidUri(checkpointURI);
        job.checkpointURI = checkpointURI;
        job.checkpointSubmitted = true;

        emit CheckpointSubmitted(jobId, msg.sender, checkpointURI);
    }

    function failCheckpoint(uint256 jobId) external whenSettlementNotPaused {
        Job storage job = _job(jobId);
        if (job.assignedAgent == address(0) || job.completed || job.expired || job.completionRequested) revert InvalidState();
        if (job.checkpointDeadline == 0 || job.checkpointSubmitted) revert InvalidState();
        if (_effectiveTimestamp(job) <= job.checkpointDeadline) revert InvalidState();

        _employerWin(jobId, job, true);
        emit CheckpointFailed(jobId, job.employer, job.assignedAgent);
    }

    function requestJobCompletion(
        uint256 jobId,
        string calldata jobCompletionURI
    ) external whenSettlementNotPaused nonReentrant {
        Job storage job = _job(jobId);
        uint256 effectiveNow = _effectiveTimestamp(job);
        if (msg.sender != job.assignedAgent) revert NotAuthorized();
        if (job.completed || job.expired || job.completionRequested) revert InvalidState();
        if (!job.disputed && effectiveNow > uint256(job.assignedAt) + job.duration) revert InvalidState();
        if (job.checkpointDeadline != 0 && !job.checkpointSubmitted && effectiveNow > job.checkpointDeadline) {
            revert InvalidState();
        }
        if (bytes(jobCompletionURI).length == 0 || bytes(jobCompletionURI).length > MAX_URI_BYTES) revert InvalidParameters();

        UriUtils.requireValidUri(jobCompletionURI);
        job.jobCompletionURI = jobCompletionURI;
        job.completionRequested = true;
        _resetPauseBaseline(job);
        job.completionRequestedAt = uint64(block.timestamp);

        emit JobCompletionRequested(jobId, msg.sender, jobCompletionURI);
        _callEnsJobPagesHook(ENS_HOOK_COMPLETION, jobId);
    }

    function validateJob(
        uint256 jobId,
        string calldata subdomain,
        bytes32[] calldata proof
    ) external whenSettlementNotPaused {
        _recordValidatorVote(jobId, subdomain, proof, true);
    }

    function disapproveJob(
        uint256 jobId,
        string calldata subdomain,
        bytes32[] calldata proof
    ) external whenSettlementNotPaused {
        _recordValidatorVote(jobId, subdomain, proof, false);
    }

    function disputeJob(uint256 jobId) external nonReentrant {
        Job storage job = _job(jobId);
        if (job.completed || job.expired) revert InvalidState();
        if (msg.sender != job.assignedAgent && msg.sender != job.employer) revert NotAuthorized();
        if (!job.completionRequested) revert InvalidState();
        if (job.disputed) revert DisputeAlreadyOpen();
        if (_effectiveTimestamp(job) > uint256(job.completionRequestedAt) + job.completionReviewPeriodSnapshot) {
            revert InvalidState();
        }

        uint256 bond = (job.payout * DISPUTE_BOND_BPS) / 10_000;
        if (bond < DISPUTE_BOND_MIN) bond = DISPUTE_BOND_MIN;
        if (bond > DISPUTE_BOND_MAX) bond = DISPUTE_BOND_MAX;
        if (bond > job.payout) bond = job.payout;

        if (bond > 0) {
            agiToken.safeTransferFrom(msg.sender, address(this), bond);
            lockedDisputeBonds += bond;
            job.disputeInitiator = msg.sender;
            job.disputeBondAmount = bond;
        }

        job.disputed = true;
        _resetPauseBaseline(job);
        job.disputedAt = uint64(block.timestamp);
        emit JobDisputed(jobId, msg.sender);
    }

    function resolveDisputeWithCode(
        uint256 jobId,
        uint8 resolutionCode,
        string calldata reason
    ) external onlyModerator whenSettlementNotPaused nonReentrant {
        Job storage job = _job(jobId);
        if (!job.disputed || job.expired) revert InvalidState();

        if (resolutionCode == 0) {
            emit DisputeResolvedWithCode(jobId, msg.sender, resolutionCode, reason);
            return;
        }

        job.disputed = false;
        job.disputedAt = 0;

        if (resolutionCode == 1) {
            _completeJob(jobId, true);
        } else if (resolutionCode == 2) {
            _employerWin(jobId, job, true);
        } else {
            revert InvalidParameters();
        }

        emit DisputeResolvedWithCode(jobId, msg.sender, resolutionCode, reason);
    }

    function resolveStaleDispute(
        uint256 jobId,
        bool employerWins
    ) external onlyOwner whenSettlementNotPaused nonReentrant {
        Job storage job = _job(jobId);
        if (!job.disputed || job.expired) revert InvalidState();
        if (_effectiveTimestamp(job) <= uint256(job.disputedAt) + job.disputeReviewPeriodSnapshot) revert InvalidState();

        job.disputed = false;
        job.disputedAt = 0;

        if (employerWins) {
            _employerWin(jobId, job, true);
        } else {
            _completeJob(jobId, true);
        }
    }

    function finalizeJob(uint256 jobId) external whenSettlementNotPaused nonReentrant {
        Job storage job = _job(jobId);
        if (job.completed || job.expired || job.disputed) revert InvalidState();
        if (!job.completionRequested) revert InvalidState();

        uint256 approvals = job.validatorApprovals;
        uint256 effectiveNow = _effectiveTimestamp(job);
        uint256 disapprovals = job.validatorDisapprovals;

        if (job.validatorApproved) {
            if (effectiveNow <= uint256(job.validatorApprovedAt) + job.challengePeriodAfterApprovalSnapshot) {
                revert InvalidState();
            }
            if (approvals > disapprovals) {
                _completeJob(jobId, true);
                return;
            }
        }

        if (effectiveNow <= uint256(job.completionRequestedAt) + job.completionReviewPeriodSnapshot) {
            revert InvalidState();
        }

        uint256 totalVotes = approvals + disapprovals;
        if (totalVotes == 0) {
            _completeJob(jobId, false);
        } else if (totalVotes < job.voteQuorumSnapshot || approvals == disapprovals) {
            job.disputed = true;
            _resetPauseBaseline(job);
            job.disputedAt = uint64(block.timestamp);
            emit JobDisputed(jobId, msg.sender);
        } else if (approvals > disapprovals) {
            _completeJob(jobId, true);
        } else {
            _employerWin(jobId, job, false);
        }
    }

    function expireJob(uint256 jobId) external whenSettlementNotPaused nonReentrant {
        Job storage job = _job(jobId);
        if (job.completed || job.expired || job.disputed) revert InvalidState();
        if (job.completionRequested) revert InvalidState();
        if (job.assignedAgent == address(0)) revert InvalidState();
        if (_effectiveTimestamp(job) <= uint256(job.assignedAt) + job.duration) revert InvalidState();

        job.expired = true;
        _decrementActive(job.assignedAgent);
        _releaseEscrow(job);

        uint256 bond = job.agentBondAmount;
        job.agentBondAmount = 0;
        if (bond > 0) {
            lockedAgentBonds -= bond;
            agiToken.safeTransfer(job.employer, bond);
        }

        agiToken.safeTransfer(job.employer, job.payout);
        _recordFailure(job.assignedAgent, job.payout, false, true);

        emit JobExpired(jobId, job.employer, job.assignedAgent, job.payout);
        _callEnsJobPagesHook(ENS_HOOK_REVOKE, jobId);
        _callEnsJobPagesHook(ENS_HOOK_LOCK, jobId);
    }

    function cancelJob(uint256 jobId) external whenSettlementNotPaused nonReentrant {
        Job storage job = _job(jobId);
        if (msg.sender != job.employer) revert NotAuthorized();
        if (job.completed || job.expired || job.assignedAgent != address(0)) revert InvalidState();

        _releaseEscrow(job);
        agiToken.safeTransfer(job.employer, job.payout);

        emit JobCancelled(jobId);
        _callEnsJobPagesHook(ENS_HOOK_REVOKE, jobId);
        _callEnsJobPagesHook(ENS_HOOK_LOCK, jobId);
        delete jobs[jobId];
    }






    function isAuthorizedAgent(
        address claimant,
        string calldata subdomain,
        bytes32[] calldata proof
    ) external view returns (bool) {
        return
            _isAuthorized(claimant, subdomain, proof, additionalAgents, agentMerkleRoot, agentRootNode, alphaAgentRootNode) &&
            !blacklistedAgents[claimant];
    }

    function isAuthorizedValidator(
        address claimant,
        string calldata subdomain,
        bytes32[] calldata proof
    ) external view returns (bool) {
        return
            _isAuthorized(claimant, subdomain, proof, additionalValidators, validatorMerkleRoot, clubRootNode, alphaClubRootNode) &&
            !blacklistedValidators[claimant];
    }

    function jobEmployerOf(uint256 jobId) external view returns (address) {
        return _job(jobId).employer;
    }

    function jobAssignedAgentOf(uint256 jobId) external view returns (address) {
        return _job(jobId).assignedAgent;
    }

    function getJobSelectionInfo(uint256 jobId)
        external
        view
        returns (
            uint8 intakeMode,
            address selectedAgent,
            bytes32 perJobAgentRoot,
            uint64 selectionExpiresAt,
            uint64 checkpointWindow,
            uint64 checkpointDeadline,
            bool checkpointSubmitted,
            address assignedAgent
        )
    {
        Job storage job = _job(jobId);
        return (
            uint8(job.intakeMode),
            job.selectedAgent,
            job.perJobAgentRoot,
            job.selectionExpiresAt,
            job.checkpointWindow,
            job.checkpointDeadline,
            job.checkpointSubmitted,
            job.assignedAgent
        );
    }

    function getJobSelectionRuntimeState(uint256 jobId)
        external
        view
        returns (uint64 selectionExpiresAt, uint256 effectiveNow, bool selectionExpired, address assignedAgent)
    {
        Job storage job = _job(jobId);
        selectionExpiresAt = job.selectionExpiresAt;
        effectiveNow = _effectiveTimestamp(job);
        selectionExpired = selectionExpiresAt != 0 && effectiveNow > selectionExpiresAt;
        assignedAgent = job.assignedAgent;
    }

    function getHighestPayoutPercentage(address agent) public view returns (uint256 highestPercentage) {
        for (uint256 i = 0; i < agiTypes.length; ++i) {
            AGIType storage agiType = agiTypes[i];
            uint256 pct = agiType.payoutPercentage;
            if (pct > highestPercentage && _erc721BalanceOf(agiType.nftAddress, agent) > 0) {
                highestPercentage = pct;
            }
        }
    }

    function addOrUpdateAGIType(address nftAddress, uint256 payoutPercentage) external onlyOwner {
        if (nftAddress == address(0) || payoutPercentage > 100) revert InvalidParameters();

        bool found;
        for (uint256 i = 0; i < agiTypes.length; ++i) {
            if (agiTypes[i].nftAddress == nftAddress) {
                agiTypes[i].payoutPercentage = payoutPercentage;
                found = true;
                break;
            }
        }

        if (!found) {
            if (agiTypes.length >= MAX_AGI_TYPES) revert InvalidParameters();
            agiTypes.push(AGIType({nftAddress: nftAddress, payoutPercentage: payoutPercentage}));
        }

        emit AGITypeUpdated(nftAddress, payoutPercentage);
    }

    function previewHistoricalScore(address agent) public view returns (uint256) {
        AgentStats memory s = agentStats[agent];

        uint256 score = reputation[agent] * 5;
        if (score > 10_000) score = 10_000;

        uint256 penalty = (uint256(s.disputeLosses) * 600) + (uint256(s.expiredJobs) * 400) + (uint256(s.failedJobs) * 100);
        if (penalty > 5_000) penalty = 5_000;

        return score > penalty ? score - penalty : 0;
    }

    function withdrawableAGI() public view returns (uint256) {
        uint256 bal = agiToken.balanceOf(address(this));
        uint256 locked = lockedEscrow + lockedAgentBonds + lockedValidatorBonds + lockedDisputeBonds;
        if (bal < locked) revert InsolventEscrowBalance();
        return bal - locked;
    }

    function withdrawAGI(uint256 amount) external onlyOwner whenPaused whenSettlementNotPaused nonReentrant {
        if (amount == 0) revert InvalidParameters();
        uint256 available = withdrawableAGI();
        if (amount > available) revert InsufficientWithdrawableBalance();
        agiToken.safeTransfer(msg.sender, amount);
        emit AGIWithdrawn(msg.sender, amount, available - amount);
    }

    function _createJob(
        address employer,
        string calldata jobSpecURI,
        uint256 payout,
        uint256 duration,
        string calldata details,
        IntakeMode intakeMode,
        bytes32 perJobAgentRoot
    ) internal whenNotPaused whenSettlementNotPaused nonReentrant returns (uint256 jobId) {
        if (employer == address(0)) revert InvalidParameters();
        if (payout == 0 || duration == 0 || payout > maxJobPayout || duration > jobDurationLimit) revert InvalidParameters();
        if (bytes(jobSpecURI).length == 0 || bytes(jobSpecURI).length > MAX_URI_BYTES) revert InvalidParameters();
        if (bytes(details).length > MAX_URI_BYTES) revert InvalidParameters();
        UriUtils.requireValidUri(jobSpecURI);

        jobId = nextJobId++;
        Job storage job = jobs[jobId];
        job.pauseSecondsBaseline = _pausedSecondsNow();
        job.employer = employer;
        job.jobSpecURI = jobSpecURI;
        job.payout = payout;
        job.duration = duration;
        job.intakeMode = intakeMode;
        job.perJobAgentRoot = perJobAgentRoot;

        agiToken.safeTransferFrom(employer, address(this), payout);
        lockedEscrow += payout;

        emit JobCreated(jobId, employer, payout, duration, jobSpecURI, intakeMode, perJobAgentRoot, details);
        _callEnsJobPagesHook(ENS_HOOK_CREATE, jobId);
    }

    function _recordValidatorVote(
        uint256 jobId,
        string calldata subdomain,
        bytes32[] calldata proof,
        bool approve
    ) internal {
        Job storage job = _job(jobId);
        if (job.completed || job.expired || job.disputed) revert InvalidState();
        if (job.assignedAgent == address(0)) revert InvalidState();
        if (blacklistedValidators[msg.sender]) revert Blacklisted();

        if (!_isAuthorized(msg.sender, subdomain, proof, additionalValidators, validatorMerkleRoot, clubRootNode, alphaClubRootNode)) {
            revert NotAuthorized();
        }

        if (!job.completionRequested) revert InvalidState();
        if (_effectiveTimestamp(job) > uint256(job.completionRequestedAt) + job.completionReviewPeriodSnapshot) revert InvalidState();
        if (job.approvals[msg.sender] || job.disapprovals[msg.sender]) revert InvalidState();
        if (job.validators.length >= MAX_VALIDATORS_PER_JOB) revert InvalidParameters();

        uint256 bond = job.validatorBondAmount;
        if (bond == 0) {
            bond = BondMath.computeValidatorBond(job.payout, validatorBondBps, validatorBondMin, validatorBondMax);
            job.validatorBondAmount = bond + 1;
        } else {
            bond -= 1;
        }

        if (bond > 0) {
            agiToken.safeTransferFrom(msg.sender, address(this), bond);
            lockedValidatorBonds += bond;
        }

        if (approve) {
            job.approvals[msg.sender] = true;
            job.validatorApprovals += 1;
            emit JobValidated(jobId, msg.sender);

            if (
                !job.validatorApproved &&
                job.requiredValidatorApprovalsSnapshot > 0 &&
                job.validatorApprovals >= job.requiredValidatorApprovalsSnapshot
            ) {
                job.validatorApproved = true;
                job.validatorApprovedAt = uint64(block.timestamp);
            }
        } else {
            job.disapprovals[msg.sender] = true;
            job.validatorDisapprovals += 1;
            emit JobDisapproved(jobId, msg.sender);

            if (
                job.requiredValidatorDisapprovalsSnapshot > 0 &&
                job.validatorDisapprovals >= job.requiredValidatorDisapprovalsSnapshot
            ) {
                job.disputed = true;
                job.disputedAt = uint64(block.timestamp);
                emit JobDisputed(jobId, msg.sender);
            }
        }

        job.validators.push(msg.sender);
    }

    function _completeJob(uint256 jobId, bool repEligible) internal {
        Job storage job = _job(jobId);
        if (job.completed || job.expired || job.disputed) revert InvalidState();

        uint256 validatorBudget = (job.payout * job.validatorRewardPctSnapshot) / 100;
        uint256 agentPayout = (job.payout * job.agentPayoutPct) / 100;

        job.completed = true;
        _decrementActive(job.assignedAgent);
        _releaseEscrow(job);
        _returnAgentBond(job, job.assignedAgent);

        uint256 reputationPoints = ReputationMath.computeReputationPoints(
            job.payout,
            job.duration,
            job.completionRequestedAt,
            job.assignedAt,
            repEligible
        );

        _growReputation(job.assignedAgent, reputationPoints);
        _recordSuccess(job.assignedAgent, job.payout);

        agiToken.safeTransfer(job.assignedAgent, agentPayout);

        if (job.validators.length == 0) {
            agiToken.safeTransfer(job.employer, validatorBudget);
        } else {
            _settleValidators(job, true, reputationPoints, validatorBudget, 0);
        }

        _mintCompletionNFT(jobId, job);
        _returnDisputeBond(job, job.assignedAgent);

        _callEnsJobPagesHook(ENS_HOOK_LOCK, jobId);
        emit JobCompleted(jobId, job.assignedAgent, reputationPoints);
    }

    function _employerWin(uint256 jobId, Job storage job, bool disputeLoss) internal {
        job.completed = true;
        job.disputed = false;
        _decrementActive(job.assignedAgent);
        _releaseEscrow(job);

        bool poolToValidators =
            job.requiredValidatorDisapprovalsSnapshot != 0 &&
            job.validatorDisapprovals >= job.requiredValidatorDisapprovalsSnapshot;
        uint256 agentBondPool = _slashOrRefundAgentBond(job, poolToValidators);

        uint256 escrowValidatorReward = job.validators.length > 0
            ? (job.payout * job.validatorRewardPctSnapshot) / 100
            : 0;

        uint256 employerRefund = escrowValidatorReward > 0 ? job.payout - escrowValidatorReward : job.payout;

        uint256 reputationPoints = ReputationMath.computeReputationPoints(
            job.payout,
            job.duration,
            job.completionRequestedAt,
            job.assignedAt,
            true
        );

        _settleValidators(job, false, reputationPoints, escrowValidatorReward, agentBondPool);
        agiToken.safeTransfer(job.employer, employerRefund);
        _returnDisputeBond(job, job.employer);

        _recordFailure(job.assignedAgent, job.payout, disputeLoss, false);

        _callEnsJobPagesHook(ENS_HOOK_REVOKE, jobId);
        _callEnsJobPagesHook(ENS_HOOK_LOCK, jobId);
        emit JobEmployerRefunded(jobId, job.employer, job.assignedAgent, employerRefund);
    }

    function _settleValidators(
        Job storage job,
        bool agentWins,
        uint256 reputationPoints,
        uint256 escrowValidatorReward,
        uint256 extraPoolForCorrect
    ) internal {
        uint256 count = job.validators.length;
        if (count == 0) return;

        uint256 bond = job.validatorBondAmount - 1;
        lockedValidatorBonds -= bond * count;
        job.validatorBondAmount = 0;

        uint256 correctCount = agentWins ? job.validatorApprovals : job.validatorDisapprovals;
        uint256 slashedPerIncorrect = (bond * job.validatorSlashBpsSnapshot) / 10_000;
        uint256 poolForCorrect = escrowValidatorReward + extraPoolForCorrect + (slashedPerIncorrect * (count - correctCount));
        uint256 perCorrectReward = correctCount > 0 ? poolForCorrect / correctCount : 0;
        uint256 validatorRepGain = (reputationPoints * job.validatorRewardPctSnapshot) / 100;

        for (uint256 i = 0; i < count; ++i) {
            address v = job.validators[i];
            bool correct = agentWins ? job.approvals[v] : job.disapprovals[v];
            uint256 payout = correct ? bond + perCorrectReward : bond - slashedPerIncorrect;
            agiToken.safeTransfer(v, payout);

            if (correct && validatorRepGain > 0) {
                _growReputation(v, validatorRepGain);
            }
        }

        uint256 consumed = perCorrectReward * correctCount;
        if (poolForCorrect > consumed) {
            agiToken.safeTransfer(agentWins ? job.assignedAgent : job.employer, poolForCorrect - consumed);
        }
    }

    function _mintCompletionNFT(uint256, Job storage job) internal {
        string memory uri = UriUtils.applyBaseIpfs(job.jobCompletionURI, baseIpfsUrl);
        uint256 tokenId = completionNFT.mintCompletion(job.employer, uri);
        emit NFTIssued(tokenId, job.employer, uri);
    }

    function _callEnsJobPagesHook(uint8 hook, uint256 jobId) internal {
        address target = ensJobPages;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, shl(224, 0x1f76f7a2))
            mstore(add(ptr, 4), hook)
            mstore(add(ptr, 36), jobId)
            pop(call(ENS_HOOK_GAS_LIMIT, target, 0, ptr, 0x44, 0, 0))
        }
    }

    function _returnAgentBond(Job storage job, address to) internal {
        uint256 bond = job.agentBondAmount;
        if (bond == 0) return;
        job.agentBondAmount = 0;
        lockedAgentBonds -= bond;
        agiToken.safeTransfer(to, bond);
    }

    function _slashOrRefundAgentBond(Job storage job, bool toPool) internal returns (uint256) {
        uint256 bond = job.agentBondAmount;
        if (bond == 0) return 0;
        job.agentBondAmount = 0;
        lockedAgentBonds -= bond;
        if (toPool) return bond;
        agiToken.safeTransfer(job.employer, bond);
        return 0;
    }

    function _returnDisputeBond(Job storage job, address to) internal {
        uint256 bond = job.disputeBondAmount;
        if (bond == 0) return;
        job.disputeBondAmount = 0;
        job.disputeInitiator = address(0);
        lockedDisputeBonds -= bond;
        agiToken.safeTransfer(to, bond);
    }

    function _growReputation(address user, uint256 points) internal {
        uint256 cur = reputation[user];
        uint256 nxt = cur + points;
        if (nxt < cur || nxt > 88_888) nxt = 88_888;
        reputation[user] = nxt;
        emit ReputationUpdated(user, nxt);
    }

    function _recordSuccess(address agent, uint256 payout) internal {
        AgentStats storage s = agentStats[agent];
        s.completedJobs += 1;
        uint256 nextVol = uint256(s.successVolume) + payout;
        s.successVolume = nextVol > type(uint128).max ? type(uint128).max : uint128(nextVol);
        s.lastOutcomeAt = uint64(block.timestamp);
    }

    function _recordFailure(address agent, uint256 payout, bool disputeLoss, bool expiredLoss) internal {
        AgentStats storage s = agentStats[agent];
        s.failedJobs += 1;
        if (disputeLoss) s.disputeLosses += 1;
        if (expiredLoss) s.expiredJobs += 1;
        uint256 nextVol = uint256(s.failVolume) + payout;
        s.failVolume = nextVol > type(uint128).max ? type(uint128).max : uint128(nextVol);
        s.lastOutcomeAt = uint64(block.timestamp);
    }

    function _decrementActive(address agent) internal {
        if (agent != address(0) && activeJobsByAgent[agent] > 0) {
            activeJobsByAgent[agent] -= 1;
        }
    }

    function _releaseEscrow(Job storage job) internal {
        if (job.escrowReleased) return;
        job.escrowReleased = true;
        lockedEscrow -= job.payout;
    }

    function _job(uint256 jobId) internal view returns (Job storage job) {
        job = jobs[jobId];
        if (job.employer == address(0)) revert JobNotFound();
    }

    function _isClockPaused() internal view returns (bool) {
        return paused() || settlementPaused;
    }

    function _handlePauseClockTransition(bool wasPaused, bool isPaused) internal {
        if (wasPaused == isPaused) return;
        if (isPaused) {
            pauseStartedAt = uint64(block.timestamp);
        } else {
            pausedSecondsAccumulated += uint64(block.timestamp) - pauseStartedAt;
        }
    }

    function _pausedSecondsNow() internal view returns (uint64) {
        if (!_isClockPaused()) return pausedSecondsAccumulated;
        return pausedSecondsAccumulated + uint64(block.timestamp) - pauseStartedAt;
    }

    function _effectiveTimestamp(Job storage job) internal view returns (uint256) {
        return block.timestamp - (_pausedSecondsNow() - uint256(job.pauseSecondsBaseline));
    }

    function _resetPauseBaseline(Job storage job) internal {
        job.pauseSecondsBaseline = _pausedSecondsNow();
    }

    function _validateValidatorThresholds(uint256 approvals, uint256 disapprovals) internal pure {
        if (
            approvals > MAX_VALIDATORS_PER_JOB ||
            disapprovals > MAX_VALIDATORS_PER_JOB ||
            approvals + disapprovals > MAX_VALIDATORS_PER_JOB
        ) revert InvalidValidatorThresholds();
    }

    function _erc721BalanceOf(address nft, address owner_) internal view returns (uint256 bal) {
        if (nft.code.length == 0) return 0;
        (bool ok, bytes memory ret) = nft.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("balanceOf(address)")), owner_)
        );
        if (ok && ret.length >= 32) {
            bal = abi.decode(ret, (uint256));
        }
    }

    function _isAuthorized(
        address claimant,
        string calldata subdomain,
        bytes32[] calldata proof,
        mapping(address => bool) storage additional,
        bytes32 merkleRoot,
        bytes32 rootNode,
        bytes32 alphaRootNode
    ) internal view returns (bool) {
        if (additional[claimant]) return true;
        if (ENSOwnership.verifyMerkleOwnership(claimant, proof, merkleRoot)) return true;
        return ENSOwnership.verifyENSOwnership(
            address(ens),
            address(nameWrapper),
            claimant,
            subdomain,
            rootNode,
            alphaRootNode
        );
    }
}
