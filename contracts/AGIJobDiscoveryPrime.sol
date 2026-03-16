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

import "./interfaces/IAGIJobManagerPrime.sol";
import "./utils/UriUtils.sol";

contract AGIJobDiscoveryPrime is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    error InvalidParameters();
    error InvalidState();
    error NotAuthorized();
    error TooManyApplicants();
    error NoWinner();
    error NoAdvanceableAction();

    uint8 public constant MAX_APPLICANTS = 64;
    uint8 public constant MAX_FINALISTS = 8;
    uint8 public constant MAX_VALIDATOR_REVEALS_PER_FINALIST = 32;

    struct PremiumJobParams {
        string jobSpecURI;
        uint256 payout;
        uint256 duration;
        string details;
    }

    struct ProcurementParams {
        uint64 commitDeadline;
        uint64 revealDeadline;
        uint64 finalistAcceptDeadline;
        uint64 trialDeadline;
        uint64 scoreCommitDeadline;
        uint64 scoreRevealDeadline;

        uint64 selectedAcceptanceWindow;
        uint64 checkpointWindow;

        uint8 finalistCount;
        uint8 minValidatorReveals;
        uint8 maxValidatorRevealsPerFinalist;

        uint16 historicalWeightBps;
        uint16 trialWeightBps;

        uint256 minReputation;
        uint256 applicationStake;
        uint256 finalistStakeTotal;
        uint256 stipendPerFinalist;
        uint256 validatorRewardPerReveal;
        uint256 validatorScoreBond;
    }

    struct Procurement {
        address employer;
        uint256 jobId;

        uint64 commitDeadline;
        uint64 revealDeadline;
        uint64 finalistAcceptDeadline;
        uint64 trialDeadline;
        uint64 scoreCommitDeadline;
        uint64 scoreRevealDeadline;

        uint64 selectedAcceptanceWindow;
        uint64 checkpointWindow;

        uint8 finalistCount;
        uint8 minValidatorReveals;
        uint8 maxValidatorRevealsPerFinalist;

        uint16 historicalWeightBps;
        uint16 trialWeightBps;

        uint256 minReputation;
        uint256 applicationStake;
        uint256 finalistStakeTotal;
        uint256 stipendPerFinalist;
        uint256 validatorRewardPerReveal;
        uint256 validatorScoreBond;

        bool shortlistFinalized;
        bool winnerFinalized;
        bool cancelled;

        address[] applicants;
        address[] finalists;
    }

    struct Application {
        bytes32 commitment;
        bool revealed;
        bool shortlisted;
        bool finalistAccepted;
        bool trialSubmitted;
        bool settled;
        bool everPromoted;

        uint256 lockedStake;
        string applicationURI;
        string trialURI;

        uint256 historicalScoreBps;
        uint256 trialScoreBps;
        uint256 compositeScoreBps;
    }

    struct ScoreCommit {
        bytes32 commitment;
        bool revealed;
        uint256 bond;
    }

    struct DiscoveryStats {
        uint32 unrevealedApplications;
        uint32 unacceptedFinals;
        uint32 noTrialFinals;
        uint64 lastDefaultAt;
    }

    IAGIJobManagerPrime public immutable settlement;
    IERC20 public immutable agiToken;

    uint256 public nextProcurementId;

    mapping(uint256 => Procurement) public procurements;
    mapping(uint256 => mapping(address => Application)) public applications;
    mapping(uint256 => mapping(address => mapping(address => ScoreCommit))) public scoreCommits;
    mapping(uint256 => mapping(address => address[])) public scoreValidators;
    mapping(uint256 => mapping(address => uint8[])) internal revealedScores;
    mapping(address => DiscoveryStats) public discoveryStats;
    mapping(address => uint256) public claimable;
    mapping(uint256 => uint256) public procurementByJobId;
    mapping(uint256 => bool) public hasProcurementByJobId;

    event ProcurementCreated(uint256 indexed procurementId, uint256 indexed jobId, address indexed employer);
    event PremiumJobCreated(uint256 indexed procurementId, uint256 indexed jobId, address indexed employer);

    event ApplicationCommitted(uint256 indexed procurementId, address indexed agent);
    event ApplicationRevealed(uint256 indexed procurementId, address indexed agent, string applicationURI);
    event ShortlistFinalized(uint256 indexed procurementId, address[] finalists);

    event FinalistAccepted(uint256 indexed procurementId, address indexed finalist, uint256 totalLockedStake);
    event TrialSubmitted(uint256 indexed procurementId, address indexed finalist, string trialURI);

    event ScoreCommitted(uint256 indexed procurementId, address indexed finalist, address indexed validator);
    event ScoreRevealed(uint256 indexed procurementId, address indexed finalist, address indexed validator, uint8 score);

    event WinnerDesignated(uint256 indexed procurementId, address indexed finalist, uint256 compositeScoreBps);
    event FallbackPromoted(uint256 indexed procurementId, address indexed finalist, uint256 compositeScoreBps);
    event ProcurementClosedWithoutWinner(uint256 indexed procurementId);
    event ProcurementCancelled(uint256 indexed procurementId, address indexed canceller);
    event Claimed(address indexed user, uint256 amount);

    constructor(address settlementAddress) {
        if (settlementAddress == address(0) || settlementAddress.code.length == 0) revert InvalidParameters();
        settlement = IAGIJobManagerPrime(settlementAddress);
        agiToken = IERC20(settlement.agiToken());
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function quoteProcurementBudget(
        uint8 finalistCount,
        uint8 maxValidatorRevealsPerFinalist,
        uint256 stipendPerFinalist,
        uint256 validatorRewardPerReveal
    ) external pure returns (uint256) {
        return uint256(finalistCount) * stipendPerFinalist
            + uint256(finalistCount) * uint256(maxValidatorRevealsPerFinalist) * validatorRewardPerReveal;
    }

    function createPremiumJobWithDiscovery(
        PremiumJobParams calldata job,
        ProcurementParams calldata proc
    ) external whenNotPaused nonReentrant returns (uint256 jobId, uint256 procurementId) {
        jobId = settlement.createConfiguredJobFor(
            msg.sender,
            job.jobSpecURI,
            job.payout,
            job.duration,
            job.details,
            1, // SelectedAgentOnly
            bytes32(0)
        );
        procurementId = _createProcurement(msg.sender, jobId, proc);
        emit PremiumJobCreated(procurementId, jobId, msg.sender);
    }

    function attachProcurementToExistingJob(
        uint256 jobId,
        ProcurementParams calldata proc
    ) external whenNotPaused nonReentrant returns (uint256 procurementId) {
        if (msg.sender != settlement.jobEmployerOf(jobId)) revert NotAuthorized();
        if (hasProcurementByJobId[jobId]) revert InvalidState();

        (
            uint8 intakeMode,
            ,
            ,
            ,
            ,
            ,
            ,
            address assignedAgent
        ) = settlement.getJobSelectionInfo(jobId);

        if (intakeMode != 1) revert InvalidState(); // must be SelectedAgentOnly
        if (assignedAgent != address(0)) revert InvalidState();

        procurementId = _createProcurement(msg.sender, jobId, proc);
    }

    function commitApplication(
        uint256 procurementId,
        bytes32 commitment,
        string calldata subdomain,
        bytes32[] calldata globalProof
    ) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (p.employer == address(0) || p.cancelled) revert InvalidState();
        if (block.timestamp > p.commitDeadline) revert InvalidState();
        if (commitment == bytes32(0)) revert InvalidParameters();
        if (!settlement.isAuthorizedAgent(msg.sender, subdomain, globalProof)) revert NotAuthorized();
        if (settlement.reputation(msg.sender) < p.minReputation) revert NotAuthorized();
        if (p.applicants.length >= MAX_APPLICANTS) revert TooManyApplicants();

        Application storage a = applications[procurementId][msg.sender];
        if (a.commitment != bytes32(0)) revert InvalidState();

        a.commitment = commitment;
        a.lockedStake = p.applicationStake;
        p.applicants.push(msg.sender);

        if (p.applicationStake > 0) {
            agiToken.safeTransferFrom(msg.sender, address(this), p.applicationStake);
        }

        emit ApplicationCommitted(procurementId, msg.sender);
    }

    function revealApplication(
        uint256 procurementId,
        string calldata subdomain,
        bytes32[] calldata globalProof,
        bytes32 salt,
        string calldata applicationURI
    ) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (p.employer == address(0) || p.cancelled) revert InvalidState();
        if (block.timestamp <= p.commitDeadline || block.timestamp > p.revealDeadline) revert InvalidState();

        Application storage a = applications[procurementId][msg.sender];
        if (a.commitment == bytes32(0) || a.revealed) revert InvalidState();
        if (!settlement.isAuthorizedAgent(msg.sender, subdomain, globalProof)) revert NotAuthorized();
        if (settlement.reputation(msg.sender) < p.minReputation) revert NotAuthorized();
        if (bytes(applicationURI).length == 0) revert InvalidParameters();

        UriUtils.requireValidUri(applicationURI);

        bytes32 expected = keccak256(abi.encodePacked(procurementId, msg.sender, applicationURI, salt));
        if (expected != a.commitment) revert NotAuthorized();

        a.revealed = true;
        a.applicationURI = applicationURI;
        a.historicalScoreBps = _snapshotHistoricalScore(msg.sender);

        emit ApplicationRevealed(procurementId, msg.sender, applicationURI);
    }

    function finalizeShortlist(uint256 procurementId) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (p.employer == address(0) || p.cancelled || p.shortlistFinalized) revert InvalidState();
        if (block.timestamp <= p.revealDeadline) revert InvalidState();

        _finalizeShortlist(procurementId, p);
    }

    function _finalizeShortlist(uint256 procurementId, Procurement storage p) internal {
        uint256 finalistsToTake = p.finalistCount;
        address[] memory topAgents = new address[](finalistsToTake);
        uint256[] memory topScores = new uint256[](finalistsToTake);

        for (uint256 i = 0; i < p.applicants.length; ++i) {
            address agent = p.applicants[i];
            Application storage a = applications[procurementId][agent];

            if (!a.revealed) {
                if (a.lockedStake > 0) {
                    claimable[p.employer] += a.lockedStake;
                    a.lockedStake = 0;
                }
                _recordDiscoveryDefault(agent, 1, 0, 0);
                continue;
            }

            uint256 historical = a.historicalScoreBps;
            uint256 insertAt = finalistsToTake;

            for (uint256 j = 0; j < finalistsToTake; ++j) {
                if (_isBetterShortlistCandidate(agent, historical, topAgents[j], topScores[j])) {
                    insertAt = j;
                    break;
                }
            }

            if (insertAt < finalistsToTake) {
                for (uint256 k = finalistsToTake - 1; k > insertAt; --k) {
                    topScores[k] = topScores[k - 1];
                    topAgents[k] = topAgents[k - 1];
                }
                topScores[insertAt] = historical;
                topAgents[insertAt] = agent;
            }
        }

        for (uint256 i = 0; i < finalistsToTake; ++i) {
            if (topAgents[i] == address(0)) break;
            applications[procurementId][topAgents[i]].shortlisted = true;
            p.finalists.push(topAgents[i]);
        }

        for (uint256 i = 0; i < p.applicants.length; ++i) {
            address agent = p.applicants[i];
            Application storage a = applications[procurementId][agent];
            if (a.revealed && !a.shortlisted && a.lockedStake > 0) {
                claimable[agent] += a.lockedStake;
                a.lockedStake = 0;
            }
        }

        p.shortlistFinalized = true;
        emit ShortlistFinalized(procurementId, p.finalists);
    }

    function cancelProcurement(uint256 procurementId) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (p.employer == address(0) || p.cancelled || p.winnerFinalized) revert InvalidState();
        if (msg.sender != p.employer && msg.sender != owner()) revert NotAuthorized();

        uint256 lenFinalists = p.finalists.length;
        for (uint256 i = 0; i < lenFinalists; ++i) {
            if (applications[procurementId][p.finalists[i]].trialSubmitted) revert InvalidState();
        }

        uint256 lenApplicants = p.applicants.length;
        for (uint256 i = 0; i < lenApplicants; ++i) {
            address applicant = p.applicants[i];
            Application storage app = applications[procurementId][applicant];
            if (app.lockedStake > 0) {
                claimable[applicant] += app.lockedStake;
                app.lockedStake = 0;
            }
        }

        for (uint256 i = 0; i < lenFinalists; ++i) {
            address finalist = p.finalists[i];
            address[] storage validators = scoreValidators[procurementId][finalist];
            for (uint256 j = 0; j < validators.length; ++j) {
                address validator = validators[j];
                ScoreCommit storage sc = scoreCommits[procurementId][finalist][validator];
                if (sc.bond > 0) {
                    claimable[validator] += sc.bond;
                    sc.bond = 0;
                }
            }
        }

        uint256 totalBudget = uint256(p.stipendPerFinalist) * p.finalistCount
            + uint256(p.validatorRewardPerReveal) * p.finalistCount * p.maxValidatorRevealsPerFinalist;

        uint256 paidValidatorRewards;
        if (p.validatorRewardPerReveal > 0) {
            for (uint256 i = 0; i < lenFinalists; ++i) {
                address finalist = p.finalists[i];
                paidValidatorRewards += uint256(revealedScores[procurementId][finalist].length) * p.validatorRewardPerReveal;
            }
        }

        if (totalBudget > paidValidatorRewards) {
            claimable[p.employer] += totalBudget - paidValidatorRewards;
        }

        p.cancelled = true;
        emit ProcurementCancelled(procurementId, msg.sender);
    }

    function acceptFinalist(uint256 procurementId) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (!p.shortlistFinalized || p.cancelled) revert InvalidState();
        if (block.timestamp > p.finalistAcceptDeadline) revert InvalidState();

        Application storage a = applications[procurementId][msg.sender];
        if (!a.shortlisted || a.finalistAccepted) revert InvalidState();

        if (p.finalistStakeTotal > a.lockedStake) {
            uint256 topUp = p.finalistStakeTotal - a.lockedStake;
            agiToken.safeTransferFrom(msg.sender, address(this), topUp);
            a.lockedStake += topUp;
        }

        a.finalistAccepted = true;
        emit FinalistAccepted(procurementId, msg.sender, a.lockedStake);
    }

    function submitTrial(
        uint256 procurementId,
        string calldata trialURI
    ) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (!p.shortlistFinalized || p.cancelled) revert InvalidState();
        if (block.timestamp > p.trialDeadline) revert InvalidState();

        Application storage a = applications[procurementId][msg.sender];
        if (!a.shortlisted || !a.finalistAccepted || a.trialSubmitted) revert InvalidState();
        if (bytes(trialURI).length == 0) revert InvalidParameters();

        UriUtils.requireValidUri(trialURI);
        a.trialSubmitted = true;
        a.trialURI = trialURI;

        emit TrialSubmitted(procurementId, msg.sender, trialURI);
    }

    function commitFinalistScore(
        uint256 procurementId,
        address finalist,
        bytes32 commitment,
        string calldata subdomain,
        bytes32[] calldata validatorProof
    ) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (p.cancelled || !p.shortlistFinalized) revert InvalidState();
        if (block.timestamp <= p.trialDeadline || block.timestamp > p.scoreCommitDeadline) revert InvalidState();
        if (commitment == bytes32(0)) revert InvalidParameters();
        if (!settlement.isAuthorizedValidator(msg.sender, subdomain, validatorProof)) revert NotAuthorized();
        if (msg.sender == p.employer) revert NotAuthorized();
        if (applications[procurementId][msg.sender].commitment != bytes32(0)) revert NotAuthorized();

        Application storage a = applications[procurementId][finalist];
        if (!a.shortlisted || !a.trialSubmitted) revert InvalidState();

        ScoreCommit storage sc = scoreCommits[procurementId][finalist][msg.sender];
        if (sc.commitment != bytes32(0)) revert InvalidState();
        if (scoreValidators[procurementId][finalist].length >= p.maxValidatorRevealsPerFinalist) revert InvalidState();

        if (p.validatorScoreBond > 0) {
            agiToken.safeTransferFrom(msg.sender, address(this), p.validatorScoreBond);
        }

        sc.commitment = commitment;
        sc.bond = p.validatorScoreBond;
        scoreValidators[procurementId][finalist].push(msg.sender);

        emit ScoreCommitted(procurementId, finalist, msg.sender);
    }

    function revealFinalistScore(
        uint256 procurementId,
        address finalist,
        uint8 score,
        bytes32 salt,
        string calldata subdomain,
        bytes32[] calldata validatorProof
    ) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (p.cancelled || !p.shortlistFinalized) revert InvalidState();
        if (block.timestamp <= p.scoreCommitDeadline || block.timestamp > p.scoreRevealDeadline) revert InvalidState();
        if (score > 100) revert InvalidParameters();
        if (!settlement.isAuthorizedValidator(msg.sender, subdomain, validatorProof)) revert NotAuthorized();
        if (applications[procurementId][msg.sender].commitment != bytes32(0)) revert NotAuthorized();

        ScoreCommit storage sc = scoreCommits[procurementId][finalist][msg.sender];
        if (sc.commitment == bytes32(0) || sc.revealed) revert InvalidState();

        bytes32 expected = keccak256(abi.encodePacked(procurementId, finalist, msg.sender, score, salt));
        if (expected != sc.commitment) revert NotAuthorized();

        sc.revealed = true;
        revealedScores[procurementId][finalist].push(score);

        claimable[msg.sender] += sc.bond + p.validatorRewardPerReveal;
        sc.bond = 0;

        emit ScoreRevealed(procurementId, finalist, msg.sender, score);
    }

    function finalizeWinner(uint256 procurementId) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (p.cancelled || !p.shortlistFinalized || p.winnerFinalized) revert InvalidState();
        if (block.timestamp <= p.scoreRevealDeadline) revert InvalidState();

        _finalizeWinner(procurementId, p);
    }

    function _finalizeWinner(uint256 procurementId, Procurement storage p) internal {
        address best;
        uint256 bestComposite;
        uint256 bestTrial;
        uint256 bestHistorical;

        uint256 stipendBudget = uint256(p.stipendPerFinalist) * p.finalistCount;
        uint256 rewardBudget = uint256(p.validatorRewardPerReveal) * p.finalistCount * p.maxValidatorRevealsPerFinalist;
        uint256 totalBudget = stipendBudget + rewardBudget;
        uint256 spentStipends;
        uint256 spentRewards;

        for (uint256 i = 0; i < p.finalists.length; ++i) {
            address finalist = p.finalists[i];
            Application storage a = applications[procurementId][finalist];

            if (!a.finalistAccepted) {
                if (a.lockedStake > 0) {
                    claimable[p.employer] += a.lockedStake;
                    a.lockedStake = 0;
                }
                _recordDiscoveryDefault(finalist, 0, 1, 0);
                a.settled = true;
                _slashNonRevealValidatorBonds(procurementId, p, finalist);
                continue;
            }

            if (!a.trialSubmitted) {
                if (a.lockedStake > 0) {
                    claimable[p.employer] += a.lockedStake;
                    a.lockedStake = 0;
                }
                _recordDiscoveryDefault(finalist, 0, 0, 1);
                a.settled = true;
                _slashNonRevealValidatorBonds(procurementId, p, finalist);
                continue;
            }

            if (!a.settled) {
                claimable[finalist] += a.lockedStake + p.stipendPerFinalist;
                spentStipends += p.stipendPerFinalist;
                a.lockedStake = 0;
                a.settled = true;
            }

            spentRewards += uint256(revealedScores[procurementId][finalist].length) * p.validatorRewardPerReveal;
            _slashNonRevealValidatorBonds(procurementId, p, finalist);

            uint8[] storage scores = revealedScores[procurementId][finalist];
            if (scores.length < p.minValidatorReveals) continue;

            uint256 trialScoreBps = _medianScoreBps(scores);
            a.trialScoreBps = trialScoreBps;

            uint256 composite = (
                a.historicalScoreBps * p.historicalWeightBps +
                trialScoreBps * p.trialWeightBps
            ) / 10_000;

            a.compositeScoreBps = composite;

            if (
                composite > bestComposite ||
                (composite == bestComposite && trialScoreBps > bestTrial) ||
                (composite == bestComposite && trialScoreBps == bestTrial && a.historicalScoreBps > bestHistorical)
            ) {
                best = finalist;
                bestComposite = composite;
                bestTrial = trialScoreBps;
                bestHistorical = a.historicalScoreBps;
            }
        }

        if (totalBudget > spentStipends + spentRewards) {
            claimable[p.employer] += totalBudget - spentStipends - spentRewards;
        }

        p.winnerFinalized = true;

        if (best == address(0)) {
            emit ProcurementClosedWithoutWinner(procurementId);
            return;
        }

        applications[procurementId][best].everPromoted = true;
        settlement.designateSelectedAgent(
            p.jobId,
            best,
            p.selectedAcceptanceWindow,
            p.checkpointWindow
        );

        emit WinnerDesignated(procurementId, best, bestComposite);
    }

    function promoteFallbackFinalist(uint256 procurementId) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (!p.winnerFinalized || p.cancelled) revert InvalidState();

        (
            ,
            ,
            ,
            uint64 selectionExpiresAt,
            ,
            ,
            ,
            address assignedAgent
        ) = settlement.getJobSelectionInfo(p.jobId);

        if (assignedAgent != address(0)) revert InvalidState();
        if (block.timestamp <= selectionExpiresAt) revert InvalidState();

        _promoteFallbackFinalist(procurementId, p);
    }

    function advanceProcurement(uint256 procurementId) external whenNotPaused nonReentrant {
        Procurement storage p = procurements[procurementId];
        if (p.employer == address(0)) revert InvalidState();
        if (p.cancelled) revert InvalidState();

        if (!p.shortlistFinalized) {
            if (block.timestamp <= p.revealDeadline) revert NoAdvanceableAction();
            _finalizeShortlist(procurementId, p);
            return;
        }

        if (!p.winnerFinalized) {
            if (block.timestamp <= p.scoreRevealDeadline) revert NoAdvanceableAction();
            _finalizeWinner(procurementId, p);
            return;
        }

        (bool selectionInfoOk, uint64 selectionExpiresAt, address assignedAgent) = _tryGetSelectionState(p.jobId);
        if (!selectionInfoOk || assignedAgent != address(0) || block.timestamp <= selectionExpiresAt) {
            revert NoAdvanceableAction();
        }
        _promoteFallbackFinalist(procurementId, p);
    }

    function canClaim(address account) external view returns (uint256) {
        return claimable[account];
    }

    function isShortlistFinalizable(uint256 procurementId) public view returns (bool) {
        if (paused()) return false;
        Procurement storage p = procurements[procurementId];
        return p.employer != address(0) && !p.cancelled && !p.shortlistFinalized && block.timestamp > p.revealDeadline;
    }

    function isWinnerFinalizable(uint256 procurementId) public view returns (bool) {
        if (paused()) return false;
        Procurement storage p = procurements[procurementId];
        if (p.cancelled || !p.shortlistFinalized || p.winnerFinalized || block.timestamp <= p.scoreRevealDeadline) return false;

        if (settlement.paused()) return false;

        bool hasDesignatableWinner = _hasDesignatableWinner(procurementId, p);
        if (!hasDesignatableWinner) return true;

        if (settlement.settlementPaused()) return false;

        return _isSelectionSlotOpen(p.jobId);
    }

    function isFallbackPromotable(uint256 procurementId) external view returns (bool) {
        return _isFallbackPromotable(procurementId);
    }

    function _isFallbackPromotable(uint256 procurementId) internal view returns (bool) {
        if (paused()) return false;
        Procurement storage p = procurements[procurementId];
        if (!p.winnerFinalized || p.cancelled) return false;

        (bool selectionInfoOk, uint64 selectionExpiresAt, address assignedAgent) = _tryGetSelectionState(p.jobId);
        if (!selectionInfoOk) return false;

        if (assignedAgent != address(0) || block.timestamp <= selectionExpiresAt) return false;

        for (uint256 i = 0; i < p.finalists.length; ++i) {
            address finalist = p.finalists[i];
            Application storage a = applications[procurementId][finalist];
            if (!_isFallbackCandidate(procurementId, p, a, finalist)) continue;
            return true;
        }
        return false;
    }

    function nextActionForProcurement(uint256 procurementId) external view returns (string memory) {
        return _nextActionForProcurement(procurementId);
    }

    function _nextActionForProcurement(uint256 procurementId) internal view returns (string memory) {
        if (paused()) return "paused";
        Procurement storage p = procurements[procurementId];
        if (p.cancelled) return "cancelled";
        if (!p.shortlistFinalized) {
            if (block.timestamp <= p.commitDeadline) return "wait_commit";
            if (block.timestamp <= p.revealDeadline) return "reveal_applications";
            return "finalize_shortlist";
        }
        if (!p.winnerFinalized) {
            if (block.timestamp <= p.finalistAcceptDeadline) return "finalists_accept";
            if (block.timestamp <= p.trialDeadline) return "submit_trials";
            if (block.timestamp <= p.scoreCommitDeadline) return "commit_scores";
            if (block.timestamp <= p.scoreRevealDeadline) return "reveal_scores";
            return "finalize_winner";
        }

        (bool selectionInfoOk, uint64 selectionExpiresAt, address assignedAgent) = _tryGetSelectionState(p.jobId);
        if (!selectionInfoOk) return "linked_job_missing";

        if (assignedAgent != address(0)) return "winner_assigned";
        if (block.timestamp <= selectionExpiresAt) return "wait_selected_acceptance";

        for (uint256 i = 0; i < p.finalists.length; ++i) {
            address finalist = p.finalists[i];
            Application storage a = applications[procurementId][finalist];
            if (!_isFallbackCandidate(procurementId, p, a, finalist)) continue;
            return "promote_fallback";
        }

        return "no_promotable_fallback";
    }

    function getAutonomyStatus(uint256 procurementId)
        external
        view
        returns (
            bool shortlistFinalizable,
            bool winnerFinalizable,
            bool fallbackPromotable,
            string memory nextAction
        )
    {
        shortlistFinalizable = isShortlistFinalizable(procurementId);
        winnerFinalizable = isWinnerFinalizable(procurementId);
        fallbackPromotable = _isFallbackPromotable(procurementId);
        nextAction = _nextActionForProcurement(procurementId);
    }

    function _hasDesignatableWinner(uint256 procurementId, Procurement storage p) internal view returns (bool) {
        uint256 bestComposite;
        uint256 bestTrial;
        uint256 bestHistorical;

        for (uint256 i = 0; i < p.finalists.length; ++i) {
            address finalist = p.finalists[i];
            Application storage a = applications[procurementId][finalist];

            if (!a.finalistAccepted || !a.trialSubmitted) continue;

            uint8[] storage scores = revealedScores[procurementId][finalist];
            if (scores.length < p.minValidatorReveals) continue;

            uint256 trialScoreBps = _medianScoreBps(scores);
            uint256 composite = (
                a.historicalScoreBps * p.historicalWeightBps +
                trialScoreBps * p.trialWeightBps
            ) / 10_000;

            if (
                composite > bestComposite ||
                (composite == bestComposite && trialScoreBps > bestTrial) ||
                (composite == bestComposite && trialScoreBps == bestTrial && a.historicalScoreBps > bestHistorical)
            ) {
                bestComposite = composite;
                bestTrial = trialScoreBps;
                bestHistorical = a.historicalScoreBps;
                return true;
            }
        }

        return false;
    }

    function _isBetterShortlistCandidate(
        address candidate,
        uint256 candidateScore,
        address incumbent,
        uint256 incumbentScore
    ) internal pure returns (bool) {
        if (incumbent == address(0)) return true;
        if (candidateScore > incumbentScore) return true;
        if (candidateScore < incumbentScore) return false;
        return uint160(candidate) < uint160(incumbent);
    }

    function _isFallbackCandidate(
        uint256 procurementId,
        Procurement storage p,
        Application storage a,
        address finalist
    ) internal view returns (bool) {
        if (a.everPromoted || !a.trialSubmitted || a.compositeScoreBps == 0) return false;
        if (revealedScores[procurementId][finalist].length < p.minValidatorReveals) return false;
        return true;
    }


    function _promoteFallbackFinalist(uint256 procurementId, Procurement storage p) internal {
        address best;
        uint256 bestComposite;
        uint256 bestTrial;
        uint256 bestHistorical;

        for (uint256 i = 0; i < p.finalists.length; ++i) {
            address finalist = p.finalists[i];
            Application storage a = applications[procurementId][finalist];

            if (!_isFallbackCandidate(procurementId, p, a, finalist)) continue;

            if (
                a.compositeScoreBps > bestComposite ||
                (a.compositeScoreBps == bestComposite && a.trialScoreBps > bestTrial) ||
                (a.compositeScoreBps == bestComposite && a.trialScoreBps == bestTrial && a.historicalScoreBps > bestHistorical)
            ) {
                bestComposite = a.compositeScoreBps;
                bestTrial = a.trialScoreBps;
                bestHistorical = a.historicalScoreBps;
                best = finalist;
            }
        }

        if (best == address(0)) revert NoWinner();

        applications[procurementId][best].everPromoted = true;
        settlement.designateSelectedAgent(
            p.jobId,
            best,
            p.selectedAcceptanceWindow,
            p.checkpointWindow
        );

        emit FallbackPromoted(procurementId, best, bestComposite);
    }

    function _isSelectionSlotOpen(uint256 jobId) internal view returns (bool) {
        (bool ok, bytes memory data) = address(settlement).staticcall(
            abi.encodeWithSelector(IAGIJobManagerPrime.getJobSelectionInfo.selector, jobId)
        );
        if (!ok || data.length == 0) return false;

        (
            uint8 intakeMode,
            ,
            ,
            uint64 selectionExpiresAt,
            ,
            ,
            ,
            address assignedAgent
        ) = abi.decode(data, (uint8, address, bytes32, uint64, uint64, uint64, bool, address));

        if (intakeMode != 1) return false;
        if (assignedAgent != address(0)) return false;
        return selectionExpiresAt == 0 || block.timestamp > selectionExpiresAt;
    }

    function _tryGetSelectionState(uint256 jobId) internal view returns (bool ok, uint64 selectionExpiresAt, address assignedAgent) {
        (bool success, bytes memory data) = address(settlement).staticcall(
            abi.encodeWithSelector(IAGIJobManagerPrime.getJobSelectionInfo.selector, jobId)
        );
        if (!success || data.length == 0) return (false, 0, address(0));

        (
            ,
            ,
            ,
            uint64 parsedSelectionExpiresAt,
            ,
            ,
            ,
            address parsedAssignedAgent
        ) = abi.decode(data, (uint8, address, bytes32, uint64, uint64, uint64, bool, address));

        return (true, parsedSelectionExpiresAt, parsedAssignedAgent);
    }

    function claim() external nonReentrant {
        uint256 amount = claimable[msg.sender];
        if (amount == 0) revert InvalidState();
        claimable[msg.sender] = 0;
        agiToken.safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    function procurementApplicants(uint256 procurementId) external view returns (address[] memory) {
        return procurements[procurementId].applicants;
    }

    function procurementFinalists(uint256 procurementId) external view returns (address[] memory) {
        return procurements[procurementId].finalists;
    }

    function applicationView(uint256 procurementId, address agent)
        external
        view
        returns (
            bool revealed,
            bool shortlisted,
            bool finalistAccepted,
            bool trialSubmitted,
            uint256 lockedStake,
            string memory applicationURI,
            string memory trialURI,
            uint256 historicalScoreBps,
            uint256 trialScoreBps,
            uint256 compositeScoreBps,
            bool everPromoted
        )
    {
        Application storage a = applications[procurementId][agent];
        return (
            a.revealed,
            a.shortlisted,
            a.finalistAccepted,
            a.trialSubmitted,
            a.lockedStake,
            a.applicationURI,
            a.trialURI,
            a.historicalScoreBps,
            a.trialScoreBps,
            a.compositeScoreBps,
            a.everPromoted
        );
    }

    function getDiscoveryStats(address agent)
        external
        view
        returns (
            uint32 unrevealedApplications,
            uint32 unacceptedFinals,
            uint32 noTrialFinals,
            uint64 lastDefaultAt,
            uint256 penaltyBps
        )
    {
        DiscoveryStats memory s = discoveryStats[agent];
        return (
            s.unrevealedApplications,
            s.unacceptedFinals,
            s.noTrialFinals,
            s.lastDefaultAt,
            previewDiscoveryPenaltyBps(agent)
        );
    }

    function previewDiscoveryPenaltyBps(address agent) public view returns (uint256) {
        DiscoveryStats memory s = discoveryStats[agent];
        uint256 base =
            uint256(s.unrevealedApplications) * 300 +
            uint256(s.unacceptedFinals) * 450 +
            uint256(s.noTrialFinals) * 600;

        if (base < 1) return 0;

        uint256 age = s.lastDefaultAt < 1 ? type(uint256).max : block.timestamp - uint256(s.lastDefaultAt);

        uint256 multiplierBps;
        if (age <= 7 days) {
            multiplierBps = 10_000;
        } else if (age >= 180 days) {
            multiplierBps = 2_500;
        } else {
            uint256 drop = ((age - 7 days) * 7_500) / (173 days);
            multiplierBps = 10_000 - drop;
        }

        uint256 penalty = (base * multiplierBps) / 10_000;
        return penalty > 5_000 ? 5_000 : penalty;
    }

    function _createProcurement(
        address employer,
        uint256 jobId,
        ProcurementParams calldata proc
    ) internal returns (uint256 procurementId) {
        if (employer == address(0)) revert InvalidParameters();
        if (proc.finalistCount == 0 || proc.finalistCount > MAX_FINALISTS) revert InvalidParameters();
        if (proc.minValidatorReveals == 0 || proc.minValidatorReveals > proc.maxValidatorRevealsPerFinalist) revert InvalidParameters();
        if (proc.maxValidatorRevealsPerFinalist == 0 || proc.maxValidatorRevealsPerFinalist > MAX_VALIDATOR_REVEALS_PER_FINALIST) {
            revert InvalidParameters();
        }
        if (proc.historicalWeightBps + proc.trialWeightBps != 10_000) revert InvalidParameters();
        if (proc.selectedAcceptanceWindow == 0) revert InvalidParameters();

        if (hasProcurementByJobId[jobId]) revert InvalidState();

        if (
            !(block.timestamp < proc.commitDeadline &&
              proc.commitDeadline < proc.revealDeadline &&
              proc.revealDeadline <= proc.finalistAcceptDeadline &&
              proc.finalistAcceptDeadline <= proc.trialDeadline &&
              proc.trialDeadline < proc.scoreCommitDeadline &&
              proc.scoreCommitDeadline < proc.scoreRevealDeadline)
        ) revert InvalidParameters();

        uint256 budget = uint256(proc.stipendPerFinalist) * proc.finalistCount
            + uint256(proc.validatorRewardPerReveal) * proc.finalistCount * proc.maxValidatorRevealsPerFinalist;

        if (budget > 0) {
            agiToken.safeTransferFrom(employer, address(this), budget);
        }

        procurementId = nextProcurementId++;
        procurementByJobId[jobId] = procurementId;
        hasProcurementByJobId[jobId] = true;
        Procurement storage p = procurements[procurementId];

        p.employer = employer;
        p.jobId = jobId;

        p.commitDeadline = proc.commitDeadline;
        p.revealDeadline = proc.revealDeadline;
        p.finalistAcceptDeadline = proc.finalistAcceptDeadline;
        p.trialDeadline = proc.trialDeadline;
        p.scoreCommitDeadline = proc.scoreCommitDeadline;
        p.scoreRevealDeadline = proc.scoreRevealDeadline;

        p.selectedAcceptanceWindow = proc.selectedAcceptanceWindow;
        p.checkpointWindow = proc.checkpointWindow;

        p.finalistCount = proc.finalistCount;
        p.minValidatorReveals = proc.minValidatorReveals;
        p.maxValidatorRevealsPerFinalist = proc.maxValidatorRevealsPerFinalist;

        p.historicalWeightBps = proc.historicalWeightBps;
        p.trialWeightBps = proc.trialWeightBps;

        p.minReputation = proc.minReputation == 0 ? settlement.premiumReputationThreshold() : proc.minReputation;
        p.applicationStake = proc.applicationStake;
        p.finalistStakeTotal = proc.finalistStakeTotal;
        p.stipendPerFinalist = proc.stipendPerFinalist;
        p.validatorRewardPerReveal = proc.validatorRewardPerReveal;
        p.validatorScoreBond = proc.validatorScoreBond;

        emit ProcurementCreated(procurementId, jobId, employer);
    }

    function _snapshotHistoricalScore(address agent) internal view returns (uint256) {
        uint256 hist = settlement.previewHistoricalScore(agent);
        uint256 penalty = previewDiscoveryPenaltyBps(agent);
        return hist > penalty ? hist - penalty : 0;
    }

    function _recordDiscoveryDefault(
        address agent,
        uint32 unrevealedInc,
        uint32 unacceptedInc,
        uint32 noTrialInc
    ) internal {
        DiscoveryStats storage s = discoveryStats[agent];
        if (unrevealedInc > 0) s.unrevealedApplications += unrevealedInc;
        if (unacceptedInc > 0) s.unacceptedFinals += unacceptedInc;
        if (noTrialInc > 0) s.noTrialFinals += noTrialInc;
        s.lastDefaultAt = uint64(block.timestamp);
    }

    function _slashNonRevealValidatorBonds(
        uint256 procurementId,
        Procurement storage p,
        address finalist
    ) internal {
        address[] storage validators = scoreValidators[procurementId][finalist];
        for (uint256 i = 0; i < validators.length; ++i) {
            address v = validators[i];
            ScoreCommit storage sc = scoreCommits[procurementId][finalist][v];
            if (!sc.revealed && sc.bond > 0) {
                claimable[p.employer] += sc.bond;
                sc.bond = 0;
            }
        }
    }

    function _medianScoreBps(uint8[] storage scores) internal view returns (uint256) {
        uint256 n = scores.length;
        uint8[] memory arr = new uint8[](n);
        for (uint256 i = 0; i < n; ++i) arr[i] = scores[i];

        for (uint256 i = 1; i < n; ++i) {
            uint8 key = arr[i];
            uint256 j = i;
            while (j > 0 && arr[j - 1] > key) {
                arr[j] = arr[j - 1];
                unchecked { --j; }
            }
            arr[j] = key;
        }

        if (n % 2 == 1) {
            return uint256(arr[n / 2]) * 100;
        } else {
            uint256 a = uint256(arr[(n / 2) - 1]);
            uint256 b = uint256(arr[n / 2]);
            return ((a + b) * 100) / 2;
        }
    }
}
