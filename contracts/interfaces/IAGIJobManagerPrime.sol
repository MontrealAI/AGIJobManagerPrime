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

interface IAGIJobManagerPrime {
    function agiToken() external view returns (address);
    function premiumReputationThreshold() external view returns (uint256);
    function settlementPaused() external view returns (bool);
    function paused() external view returns (bool);

    function createConfiguredJobFor(
        address employer,
        string calldata jobSpecURI,
        uint256 payout,
        uint256 duration,
        string calldata details,
        uint8 intakeMode,
        bytes32 perJobAgentRoot
    ) external returns (uint256 jobId);

    function jobEmployerOf(uint256 jobId) external view returns (address);
    function jobAssignedAgentOf(uint256 jobId) external view returns (address);

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
        );



    function getJobSelectionRuntimeState(uint256 jobId)
        external
        view
        returns (bool selectionExpiredOrOpen, address assignedAgent);

    function reputation(address agent) external view returns (uint256);
    function previewHistoricalScore(address agent) external view returns (uint256);

    function isAuthorizedAgent(
        address claimant,
        string calldata subdomain,
        bytes32[] calldata proof
    ) external view returns (bool);

    function isAuthorizedValidator(
        address claimant,
        string calldata subdomain,
        bytes32[] calldata proof
    ) external view returns (bool);

    function designateSelectedAgent(
        uint256 jobId,
        address selectedAgent,
        uint64 acceptanceWindow,
        uint64 checkpointWindow
    ) external;

    function setPerJobAgentRoot(
        uint256 jobId,
        bytes32 root,
        uint64 applicationWindow
    ) external;

    function setEnsJobPages(address target) external;
    function ensJobPages() external view returns (address);

}
