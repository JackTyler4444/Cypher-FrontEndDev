/**
* Main Ethereum client services integration class for CypherPoker.
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package {

	import flash.events.EventDispatcher;
	import EthereumWeb3Client;
	import flash.external.ExternalInterface;
	import org.cg.EthereumConsoleView;
	import org.cg.DebugView;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import org.cg.SmartContract;
	import org.cg.events.EthereumEvent;
	import org.cg.GlobalSettings;
	
	public class Ethereum extends EventDispatcher {
		
		private var _ethereumClient:EthereumWeb3Client = null;
		private var _ethAddrMap:Array = new Array(); //.ethAddr, .peerID
		private var _syncStatusTimer:Timer = null; //used to monitor the client sync status
		private var _syncStatusInfo:Object = null; //gathers running client sync statistics
		private var _peerIDMap:Object = new Object(); //Ethereum-account-indexed mapping of clique peer IDs (_peerIDMap[ethAccount]=peerID)
		private var _account:String = null; //main Ethereum user account
		private var _password:String = null; //main Ethereum user account's password
		private var _deployGasAmount:Number = 4000000; //default gas amount to use to deploy new contracts
		private static var _nonceIndex:Number = 0; //sequential index value used with "nonce" getter
		private var _accountUnlockDuration:uint = 1200; //duration, in seconds, to keep the current account unlocked when unlocking
		
		/**
		 * Creates a new instance of the Ethereum class.
		 * 
		 * @param	clientRef A reference to an active EthereumWeb3Client instance.
		 */
		public function Ethereum(clientRef:EthereumWeb3Client) {
			_ethereumClient = clientRef;
		}
		/**
		 * A reference to the exposed Ethereum Web3 object.
		 */
		public function get web3():Object {
			return (_ethereumClient.web3);
		}
		
		/**
		 * A reference to the associated EthereumWeb3Client instance.
		 */
		public function get client():EthereumWeb3Client {			
			return (_ethereumClient);
		}
		
		/**
		 * Main Ethereum user account to use for most operations.
		 */
		public function get account():String {
			return (this._account);
		}
		
		public function set account(accountSet:String):void {
			this._account = accountSet;
		}
		
		/**
		 * @return An array of all currently mapped Ethereum addresses.
		 */
		public function get allRegAddresses():Array {
			var returnArray:Array = new Array();
			for (var count:uint = 0; count < _ethAddrMap.length; count++) {
				returnArray.push(_ethAddrMap[count].ethAddr);
			}
			return (returnArray);
		}
		
		/**
		 * Duration, in seconds, to keep the current account unlocked when used in conjunction with the "unlockAccount" method. Because
		 * unlocking the account causes runtime hiccups it's advisable to keep use a high value. Default is 1200 (20 minutes).
		 */
		public function set accountUnlockDuration(durationSet:uint):void {
			this._accountUnlockDuration = durationSet;
		}
		
		public function get accountUnlockDuration():uint {
			return (this._accountUnlockDuration);
		}
		
		/**
		 * Default gas amount to use when deploying new contracts.
		 */
		public function set deployGasAmount(gasAmount:Number):void {
			this._deployGasAmount = gasAmount;
		}
		
		public function get deployGasAmount():Number {
			return (this._deployGasAmount);
		}
		
		/**
		 * Password associated with main Ethereum user account to use for most operations. If this value is null or an empty string
		 * the user should be prompted to enter the information into a password masking field.
		 */
		public function get password():String {
			return (this._password);
		}
		
		public function set password(passwordSet:String):void {
			this._password = passwordSet;
		}
		
		/**
		 * Generates a unique, sequential nonce value every time it's accessed.
		 */
		public function get nonce():String {
			var dateObj:Date = new Date();
			var ts:String = new String();
			ts += String(dateObj.getUTCFullYear())
			if ((dateObj.getUTCMonth()+1) <= 9) {
				ts += "0";
			}
			ts += String((dateObj.getUTCMonth()+1));
			if ((dateObj.getUTCDate()) <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCDate());
			if (dateObj.getUTCHours() <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCHours());
			if (dateObj.getUTCMinutes() <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCMinutes());
			if (dateObj.getUTCSeconds() <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCSeconds());
			if (dateObj.getUTCMilliseconds() <= 9) {
				ts += "0";
			}
			if (dateObj.getUTCMilliseconds() <= 99) {
				ts += "0";
			}
			ts += String(dateObj.getUTCMilliseconds());			
			ts += String(_nonceIndex);
			_nonceIndex++;
			return (ts);
		}		
		
		/**
		 * Unlocks the Ethereum account for the duration specified in the "accountUnlockDuration" duration.
		 * 
		 * @param	accountVal The account to unlock. If omitted the current "account" value is used.
		 * @param	passwordVal The password to use to unlock the account. If omitted the current "password" value is used.
		 * 
		 * @return True if the account was successfully unlocked or is currently unlocked, false otherwise.
		 */
		public function unlockAccount(accountVal:String = null, passwordVal:String = null):Boolean {
			if (accountVal == null) {
				accountVal = this.account;
			}
			if (passwordVal == null) {
				passwordVal = this.password;
			}
			if ((accountVal == null) || (accountVal == "")) {
				return (false);
			}
			if ((passwordVal == null) || (passwordVal == "")) {
				return (false);
			}
			//Geth
			return (client.lib.unlockAccount(accountVal, passwordVal, this.accountUnlockDuration));
			//Parity
			//return (client.lib.unlockAccount(accountVal, passwordVal, this.addHexPrefix(this.accountUnlockDuration.toString(16))));
		}
		
		/**
		 * Maps or associates an Ethereum account address to a clique peer ID.
		 * 
		 * @param	account The Ethereum account address to associate with a peer ID.
		 * @param	peerID The clique peer ID to associate with the Ethereum account address.
		 */
		public function mapPeerID(account:String, peerID:String):void {
			this._ethAddrMap[account] = peerID;
		}
		
		/**
		 * Attempts to find a clique peer ID associated with an Ethereum account address.
		 * 
		 * @param	account The Ethereum account address for which to find an associated peer ID.
		 * 
		 * @return The clique peer ID associated with the specified Ethereum account address or null if none can be found.
		 */
		public function getPeerIDByAccount(account:String):String {
			try {
				return (this._ethAddrMap[account]);
			} catch (err:*) {				
			}
			return (null);
		}
		
		/**
		 * Attempts to find a an Ethereum account address associated with a clique peer ID.
		 * 
		 * @param	account The clique peer ID for which to find an associated Ethereum account address.
		 * 
		 * @return The Ethereum account address associated with the specified clique peer ID or null if none can be found.
		 */
		public function getAccountByPeerID(peerID:String):String {
			for (var accountAddr:String in this._ethAddrMap) {
				var currentPeerID:String = this._ethAddrMap[accountAddr];
				if (peerID == currentPeerID) {
					return (accountAddr);
				}
			}
			return (null);
		}
		
		/**
		 * Returns the balance of an Ethereum account associated with a specific peer ID.
		 * 
		 * @param	peerID The peer ID associated with the Ethereum account.
		 * @param	denomination The denomination in which to return the balance, if available.
		 * 
		 * @return The Ethereum account balance of the associated peer ID or null.
		 */
		public function getPeerBalance(peerID:String, denomination:String="ether"):String {						
			var ethAddr:String = getEthereumAddress(peerID);						
			if (ethAddr!=null) {
				try {
					var balance:String = client.lib.getBalance(ethAddr, denomination);					
					return (balance);					
				} catch (err:*) {
					return (null);
				}
			}
			return (null);
		}
		
		/**
		 * Maps a CypherPoker peer ID to an Ethereum address.
		 * 
		 * @param	peerID The CypherPoker peer ID to associate with an Ethereum address.
		 * @param	ethAddr The Ethereum address to associate with the CypherPoker peer ID.
		 * 
		 * @return True if the mapping was successfully completed.
		 */
		public function mapPeerIDToEthAddr(peerID:String, ethAddr:String):Boolean {
			var mapObj:Object = new Object();
			mapObj.peerID = peerID;
			mapObj.ethAddr = ethAddr;
			_ethAddrMap.push(mapObj);
			return (true);
		}
		
		/**
		 * Finds a specific Ethereum address based on a CypherPoker peer ID.
		 * 
		 * @param	peerID The CypherPoker peer ID for which to find an associated Etherem address.
		 *
		 * @return The Ethereum address associated with the peer ID or null if none can be found.
		 */
		public function getEthereumAddress(peerID:String):String {
			for (var count:uint = 0; count < _ethAddrMap.length; count++) {
				if (_ethAddrMap[count].peerID == peerID) {
					return (_ethAddrMap[count].ethAddr);
				}
			}
			return (null);
		}
		
		/**
		 * Signs data with the current account's private signature after hashing it with SHA3. The "account" and "password" properties
		 * must be set and access to the Etherum client must be available prior to calling this function.
		 * 
		 * @param	inputData Either a single string or array of strings (to be concatenated using the delimiter), to be signed. The nonce will
		 * be concatenated to the end of this string using the delimiter.
		 * @param   useNonce If true, a nonce is generated and appended to the input data. (See "nonce" getter")
		 * @param	delimiter If using a nonce this string will be appended to the input data before appending the nonce.
		 * 
		 * @return Object containing the composite "message", the ouput "signature", the signing "account", the "nonce" (an empty string if none used), 
		 * the "delimiter", and the SHA3/Keccak "hash" of "message".
		 */
		public function sign (inputData:*, useNonce:Boolean = true, delimiter:String = ":"):Object {
			var returnObj:Object = new Object();			
			if (useNonce) {	
				returnObj.nonce = nonce;
				returnObj.delimiter = delimiter;
			} else {
				returnObj.nonce = "";
				returnObj.delimiter = "";				
			}
			if (inputData is String) {
				returnObj.message = inputData;
			} else {
				if ((inputData["length"] == undefined) || (inputData["length"] == null) || ((inputData["join"] is Function) == false)) {
					var err:Error = new Error("Ethereum.sign: inputData is neither a string or array object; cannot create signed data.");
					throw (err);
				}
				returnObj.message = inputData.join(delimiter);
			}
			if (returnObj.nonce != "") {				
				returnObj.message = returnObj.message + returnObj.delimiter + returnObj.nonce;
			}
			returnObj.account = account;
			returnObj.hash = this.addHexPrefix(web3.sha3(returnObj.message));  //requires "0x" prefix!
			if (this.unlockAccount() == false) {
				err = new Error("Ethereum.sign: Couldn't unlock account for data signing. Account and/or password incorrect or not set.");
				throw (err);				
			}
			//don't use use personal.sign because it requires full credentials (slow)
			returnObj.signature = web3.eth.sign(account, returnObj.hash);
			return (returnObj);
		}
		
		/**
		 * Starts mining within the Ethereum client. Note that it is possible to control mining operations directly through the
		 * web3 object but this is the preferred method as it dispatches an event to notify any listening components of the operation.
		 * 
		 * @param	miningThreads The number of threads to use for the mining operation.
		 * 
		 * @return True if mining was successfully started, false if there was a problem: no valid client instance exists, no default
		 * coinbase has been set, mining is already active, or miningThreads is not a valid value.
		 */
		public function startMining(miningThreads:*):Boolean {
			DebugView.addText ("Ethereum.startMining: using " + miningThreads+ " threads");
			if (this.web3 == null) {
				return (false);
			}
			if ((this.web3.eth.coinbase == null) || (this.web3.eth.coinbase == "0x") || (this.web3.eth.coinbase == "")) {
				return (false);
			}
			if (this.web3.eth.mining) {
				return (false);
			}
			try {
				miningThreads = Number(miningThreads);
				if (isNaN(miningThreads)) {
					miningThreads = 0;
				}
				if (Math.floor(miningThreads) != miningThreads) {
					//not an integer
					miningThreads = 0;
				}
			} catch (err:*) {
				miningThreads = 0;
			}
			if (miningThreads < 1) {
				return (false);
			}			
			var event:EthereumEvent = new EthereumEvent(EthereumEvent.MINING_START);
			event.numThreads = uint(miningThreads);
			this.dispatchEvent(event);
			this.web3.miner.start(miningThreads);
			return (true);
		}
		
		/**
		 * Stops any active mining operation in the client. Although it's posssible to stop mining directly through the web3
		 * object it's advisable to use this function as it dispatches an event to any listening components that may need to
		 * be notified of this status.
		 * 
		 * @return True if mining could be stopped, false if there was a problem: the web3 object isn't available, or mining wasn't active
		 */
		public function stopMining():Boolean {
			if (this.web3 == null) {
				return (false);
			}
			if (!this.web3.eth.mining) {
				return (false);
			}
			this.web3.miner.stop();
			var event:EthereumEvent = new EthereumEvent(EthereumEvent.MINING_STOP);
			this.dispatchEvent(event);
			return (true);
		}
		
		/**
		 * Begins monitoring the sync status of the Ethereum client.
		 * 
		 * @param	interval The interval, in seconds, on which to monitor the sync status. It is recommended to keep this at the default value.
		 */
		public function startMonitorSyncStatus(interval:Number = 3):void {
			if (this._syncStatusTimer != null) {
				this._syncStatusTimer.removeEventListener(TimerEvent.TIMER, this.onMonitorSyncStatus);
				this._syncStatusTimer.stop();
				this._syncStatusTimer = null;
			}
			this._syncStatusTimer = new Timer(interval * 1000);
			this._syncStatusInfo = new Object();
			this._syncStatusInfo.lastBlockCount = -1;
			this._syncStatusInfo.averageBlocksPerSecond = 0;
			this._syncStatusTimer.addEventListener(TimerEvent.TIMER, this.onMonitorSyncStatus);
			this._syncStatusTimer.start();
		}
		
		/**
		 * Stops any current sync status monitoring of the Ethereum client.
		 *
		 */
		public function stopMonitorSyncStatus():void {
			if (this._syncStatusTimer != null) {
				this._syncStatusTimer.removeEventListener(TimerEvent.TIMER, this.onMonitorSyncStatus);
				this._syncStatusTimer.stop();
				this._syncStatusTimer = null;
			}
		}
		
		/**		 
		 * Generates a deployed libraries object for a specific network ID for use in methods like deployLinkedContracts, from settings XML data in
		 * <smartcontracts>..<ethereum>
		 * 
		 * @param	client The name of the client for which to generate a libraries object. Default is "ethereum".
		 * @param	networkID The ID of the network for which to generate the libraries iobject. Default is 1.
		 * 
		 * @return A generated object containing name/value pairs found in the associated settings data, or null if no such data exists.
		 */
		public function generateDeployedLibsObj(client:String = "ethereum", networkID:int = 1):* {
			if (networkID < 0) {
				return (null);
			}
			try {
				var ethereumNode:XML = GlobalSettings.getSetting("smartcontracts", "ethereum");
				var networkNodes:XMLList = ethereumNode.child("network") as XMLList;				
				for (var count:int = 0; count < networkNodes.length(); count++) {
					var currentNetworkNode:XML = networkNodes[count] as XML;
					var currentNetworkID:int = int(currentNetworkNode.@id);
					if (currentNetworkID == networkID) {
						var returnObj:Object = new Object();
						var contractNodes:XMLList = currentNetworkNode.children() as XMLList;
						for (var count2:int = 0; count2 < contractNodes.length(); count2++) {							
							var contractNode:XML = contractNodes[count2] as XML;
							if (String(contractNode.@type) == "library") {
								var libraryName:String = new String(contractNode.localName());
								var address:String = String(contractNode.child("address")[0].toString());
								returnObj[libraryName] = address;								
							}
						}
						return (returnObj);
					}
				}			
			} catch (err:*) {				
			}
			return (null);
		}
		
		/**
		 * Deploys a single or multiple compiled contract(s) that may require linking. Non-linking contracts and libraries are deployed first and 
		 * subsequent contracts are dynamically linked as required.
		 * 
		 * @param	contractsData Compiled contract(s) data as would be created by utilities such as the solc compiler. The top-level object must be named
		 * "contracts" and child contracts are stored in name-value pairs within it. Each child contract object must contain an "abi" string definition and
		 * "bin" string with compiled binary contract data. A "deployedAt" property will be added to each child contract object as the deployed
		 * contract address is determined; this property will be used to link dependent contracts.			 
		 * @param   params Optional instantiation parameters to use to deploy the various contracts. The name of each name/value pair should match one of the
		 * contracts being deployed and its property should be an array (used in order in a Function.call operation). For example: params.PokerHandData=["0x909a09...
		 * @param 	account The account to use/debit to deploy the contract(s).
		 * @param	password The password to use to unlock the deploying account.
		 * @param   deployedContracts Optional name-value pairs of existing contract/library addresses (e.g deployedContracts.myContract="0x90a901..."). 
		 * Any deployed contracts within contractsData are assumed to already exist on the target blockchain (i.e. they will not be deployed), 
		 * and their associated "deployedAt" property will be set.
		 * 
		 */
		public function deployLinkedContracts(contractsData:Object, params:Object, account:String, password:String, deployedContracts:Object = null):void {
			DebugView.addText("Ethereum.deployLinkedContracts");
			//link already deployed contracts first
			if (deployedContracts != null) {
				DebugView.addText("   Linking existing contract/library addresses:");
				for (var deployedContract:String in deployedContracts) {
					for (var currentContract:String in contractsData.contracts) {
						if (currentContract == deployedContract) {
							contractsData.contracts[currentContract].deployedAt = deployedContracts[deployedContract];	
							DebugView.addText ("      \""+deployedContract+"\" deployed at " + contractsData.contracts[currentContract].deployedAt);
							this.linkContract(currentContract, deployedContracts[deployedContract], contractsData);
						}
					}
				}
			}
			contractsData.params = params;
			contractsData.account = account;
			contractsData.password = password;
			for (currentContract in contractsData.contracts) {
				var currentContractObj:Object = contractsData.contracts[currentContract];
				if (this.contractDeployable(currentContractObj)) {
					var linkName:String = this.contractLinkName(currentContract);
					if ((contractsData.params[currentContract] != undefined) && (contractsData.params[currentContract] != null)) {
						var contractParams:Array = contractsData.params[currentContract] as Array;
					} else {
						contractParams = [];
					}
					this.deployContract(JSON.stringify(contractsData), currentContract, contractParams, currentContractObj.abi, currentContractObj.bin, contractsData.account, contractsData.password, this.onDeployContract, this._deployGasAmount);
				}
			}
		}
		
		/**
		 * Deploys a compiled contract to the current Ethereum blockchain.
		 * 
		 * @param	A JSON-encoded string representing the compiled contract(s) currently being processed. This data will be returned in the callback
		 * so that subsequent processing can take place.
		 * @param	contractName The name of the contract to be deployed. This information will be included with the parameters in the callback.
		 * @param 	params Optional instantiation parameters to pass to the associated contract, used in order in a Function.call operation. Use [] for no parameters.
		 * @param	abiStr The contract's JSON-encoded interface (ABI).
		 * @param	bytecode The contract's bytecode. Ensure that any libraries have been linked prior to including this data.
		 * @param	account The account from which to public the contract.
		 * @param	password The password to use to unlock the publishing account.
		 * @param	callback An optional callback function that is invoked during various stages of the deployment.
		 * @param	gas An optional gas amount to use to publish the contract with. If omitted or 0, the default gas amount is used (specified in the cypherpokerlib.js file).
		 * 
		 * @return An immediate return object containing the hash and address of the (as yet non-deployed) contract. Null is returned if there was a problem
		 * during deployment.
		 */
		public function deployContract (contractsData:String, contractName:String, params:Array, abiStr:String, bytecode:String, account:String, password: String, callback:Function = null, gas:uint = 0):Object {	
			try {
				return (_ethereumClient.lib.deployContract(contractsData, contractName, JSON.stringify(params), abiStr, bytecode, account, password, callback, gas));
			} catch (err:*) {				
			}
			return (null);
		}
		
		/**
		 * Callback function invoked by the CypherPoker JavaScript Ethereum library during a contract deployment operation. This function may be invoked
		 * multiple times for a single contract during deployment.
		 * 
		 * @param	contractsData JSON-encoded contract(s) data containing deployment state(s) and addresses.
		 * @param	contractName The name of the contract that was just deployed.
		 * @param	error An error associated with the contract deployment (will be null if no error occured).
		 * @param	contract An object containing the contract data ("address" property will be undefined if contract has yet to be mined).
		 */
		public function onDeployContract(contractsData:String, contractName:String, error:Object=null, contract:Object=null):void {
			DebugView.addText ("Ethereum.onDeployContract: " + contractName);
			if (error != null) {
				DebugView.addText ("   Error: " + String(error));
				var newEvent:EthereumEvent = new EthereumEvent(EthereumEvent.DEPLOYERROR);
				newEvent.contractAddress = String(contract["address"]);
				newEvent.txhash = String(contract["transactionHash"]);
				newEvent.deployData = contractsData;
				newEvent.error = String(error);
				this.dispatchEvent(newEvent);
				return;
			} else {
				newEvent = new EthereumEvent(EthereumEvent.CONTRACTDEPLOYED);
				newEvent.contractAddress = String(contract["address"]);
				newEvent.txhash = String(contract["transactionHash"]);
				newEvent.deployData = contractsData;
			}
			if ((contract["address"] != undefined) && (contract["address"] != null) && (contract["address"] != "")) {
				DebugView.addText("   Contract address: " + String(contract["address"]));
				DebugView.addText("   Transaction hash: "+String(contract["transactionHash"]));
				var contractsDataObj:Object = JSON.parse(contractsData);
				var linkName:String = this.contractLinkName(contractName);
				for (var currentContractName:String in contractsDataObj.contracts) {
					var currentContractObj:Object = contractsDataObj.contracts[currentContractName];
					if (currentContractName == contractName) {
						//flag contract as deployed
						currentContractObj.deployedAt = String(contract["address"]);
						break;
					}
				}
				this.linkContract(contractName, String(contract["address"]), contractsDataObj);
				if (allContractsDeployed(contractsDataObj)) {
					newEvent = new EthereumEvent(EthereumEvent.CONTRACTSDEPLOYED);
					newEvent.contractName = contractName;
					newEvent.contractAddress = String(contract["address"]);
					newEvent.txhash = String(contract["transactionHash"]);
					var parsedData:Object = JSON.parse(contractsData);
					for (currentContractName in parsedData.contracts) {
						if (currentContractName == contractName) {
							newEvent.contractInterface = parsedData.contracts[currentContractName].abi;
							break;
						}
					}					
					newEvent.deployData = contractsData;
					this.dispatchEvent(newEvent);
					return;
				}
				for (currentContractName in contractsDataObj.contracts) {
					currentContractObj = contractsDataObj.contracts[currentContractName];				
					if (this.contractDeployable(currentContractObj)) {
						linkName = this.contractLinkName(currentContractName);
						if ((contractsDataObj.params[currentContractName] != undefined) && (contractsDataObj.params[currentContractName] != null)) {
							var contractParams:Array = contractsDataObj.params[currentContractName] as Array;
						} else {
							contractParams = [];
						}
						this.deployContract(JSON.stringify(currentContractObj), currentContractName, contractParams, currentContractObj.abi, currentContractObj.bin, contractsDataObj.account, contractsDataObj.password, this.onDeployContract, this._deployGasAmount);						
					}
				}
			} else {
				DebugView.addText ("   Contract in mining queue.");
				DebugView.addText ("   Pending transaction hash: " + String(contract["transactionHash"]));
				newEvent = new EthereumEvent(EthereumEvent.CONTRACTDEPLOYING);
				newEvent.deployData = contractsData;
				newEvent.txhash = String(contract["transactionHash"]);
				this.dispatchEvent(newEvent);
			}
		}
		
		/**
		 * Prepares the instance to be destroyed by removing any references and lsteners.
		 */
		public function destroy():void {
			var newEvent:EthereumEvent = new EthereumEvent(EthereumEvent.DESTROY);			
			this.dispatchEvent(newEvent);
			this.client.destroy();			
			this.stopMonitorSyncStatus();
			this._ethereumClient = null;
			this._syncStatusInfo = null;
			this._peerIDMap = null;
			this.account = "";
			if (this.password != null) {
				//scrub password
				for (var count:int = 0; count < this.password.length; count++) {
					this.password.replace(this.password.substr(count, 1), "X");				
				}
				this.password = null;
			}
		}
		
		/**
		 * Event handler invoked when the monitor sync status timer fires.
		 * 
		 * @param	eventObj A TimerEvent object.
		 */
		private function onMonitorSyncStatus(eventObj:TimerEvent):void {
			var newEvent:EthereumEvent = new EthereumEvent(EthereumEvent.CLIENTSYNCEVENT);		
			try {
				if (client.web3.eth.syncing == false) {
					if (client.web3.net.peerCount == 0) {
						newEvent.syncInfo.status =-2;
						newEvent.syncInfo.statusText = "Waiting for peer connections";
					} else {
						newEvent.syncInfo.status =-1;
						newEvent.syncInfo.statusText = "Waiting for first sync response";
					}
					this.dispatchEvent(newEvent);
					return;
				}
			} catch (err:*) {
				newEvent.syncInfo.status =-3;
				newEvent.syncInfo.statusText = "Waiting for client ready";
				this.dispatchEvent(newEvent);
				return;
			}
			newEvent.syncInfo.statusText = "Syncing";
			newEvent.syncInfo.status = 1;
			var syncStatusObj:Object = client.web3.eth.syncing;
			newEvent.syncInfo.percentComplete = (Number(syncStatusObj.currentBlock) / Number(syncStatusObj.highestBlock)) * 100;
			if (newEvent.syncInfo.percentComplete == 100) {
				newEvent.syncInfo.statusText = "Awaiting new blocks";
				newEvent.syncInfo.status = 2;
			}
			newEvent.syncInfo.percentRemaining = 100 - newEvent.syncInfo.percentComplete;
			newEvent.syncInfo.blocksRemaining = Number(syncStatusObj.highestBlock) - Number(syncStatusObj.currentBlock);
			newEvent.syncInfo.currentBlock =  Number(syncStatusObj.currentBlock);
			newEvent.syncInfo.highestBlock =  Number(syncStatusObj.highestBlock);			
			if (this._syncStatusInfo.lastBlockCount > -1) {
				newEvent.syncInfo.blocksPerSecond = (this._syncStatusInfo.lastBlockCount - newEvent.syncInfo.blocksRemaining) / (this._syncStatusTimer.delay / 1000);
				this._syncStatusInfo.averageBlocksPerSecond = (this._syncStatusInfo.averageBlocksPerSecond + newEvent.syncInfo.blocksPerSecond) / 2;
				newEvent.syncInfo.averageBlocksPerSecond = this._syncStatusInfo.averageBlocksPerSecond;
			}
			this._syncStatusInfo.lastBlockCount = newEvent.syncInfo.blocksRemaining;
			this.dispatchEvent(newEvent);
		}
		
		/**
		 * Links a deployed contract/library within binary data of other contracts that specify it.
		 * 
		 * @param	contractName The name of the deployed contract being linked as it appears in the compiled contract data.
		 * @param	address The deployed address of the contract being linked.
		 * @param	contractsData Compiled contract(s) data as would be created by utilities such as the solc compiler, containing contracts
		 * that may require linking to the current contract.
		 */
		private function linkContract(contractName:String, address:String, contractsData:Object):void {
			var linkName:String = contractLinkName(contractName);
			address = address.split("0x").join(""); //strip leading "0x" if included
			for (var contract:String in contractsData.contracts) {
				var currentContract:Object = contractsData.contracts[contract];
				if (!this.contractDeployed(currentContract)) {
					DebugView.addText ("   Linking contract/library \"" + contractName+"\" at " + address + " in contract \"" + contract + "\".");
					var splitData:Array = currentContract.bin.split(linkName);
					DebugView.addText("       Updated " + (splitData.length-1) + " links.");
					currentContract.bin=splitData.join(address);
				}
			}
		}
		
		/**
		 * Determines whether or not a specified contract object is deployable. A non-deployable contract is one that includes link
		 * identifiers that have not yet been substituted with deployed contract/library addresses, or one that has already been deployed
		 * (includes a valid "deployedAt" property).
		 * 		 
		 * @param	contractRef The compiled contract object to check for deployability.
		 * @param	padChar The standard padding character used when generating dynamic link identifiers.
		 * 
		 * @return True if the contract contains no dynamic link identifiers or deployedAt address and therefore may be deployed.
		 */
		private function contractDeployable(contractRef:Object, padChar:String = "_"):Boolean {			
			if (contractRef.bin.indexOf(padChar) > -1) {
				return (false);
			}
			if ((contractRef["deployedAt"]!=undefined) && (contractRef["deployedAt"]!=null) && (contractRef["deployedAt"]!="")) {
				return (false);
			}
			return (true);
		}
		
		/**
		 * Determines whether a current contract object, as compiled by a utility such as solc, has already been deployed by
		 * checking its "deployedAt" property. This method does NOT check if the contract exists on the blockchain.
		 * 
		 * @param	contractRef The contract object to analyze.
		 * 
		 * @return True of the contract has already been deployed (has a valid Ethereum address).
		 */
		private function contractDeployed(contractRef:Object):Boolean {
			//should we also check for length?
			if ((contractRef["deployedAt"] != undefined) && (contractRef["deployedAt"] != null) && (contractRef["deployedAt"] != "")) {
				return (true);
			}
			return (false);
		}
		
		/**
		 * Produces an padded dynamic link name for a contract. The padded link name is usually used to dynamically link deployed contracts and libraries
		 * within other contracts.
		 * 
		 * @param	contractName The contract name for which to produce a link name.
		 * @param	linkLength The length of the output paddded link string.
		 * @param	padChar The padding character to use to produce the output link string.
		 * 
		 * @return The contract link name that may be used to search and replace dynamic contract/library addresses within compiled contract data.
		 */
		private function contractLinkName(contractName:String, linkLength:Number=40, padChar:String="_"):String {
			var returnName:String = padChar+padChar+contractName;
			for (var count:int = returnName.length; count < linkLength; count++) {
				returnName+= padChar;
			}
			return (returnName);
		}
		
		/**
		 * Checks the "deployedAt" property of the contracts in a multi-contract object to determine if all contracts have been deployed.
		 * 
		 * @param	contractsData An object containing multiple contracts within a "contracts" object.
		 * 
		 * @return True if all contained contracts have been deployed (have a valid "deployedAt" property), false otherwise.
		 */
		private function allContractsDeployed(contractsData:Object):Boolean {
			for (var currentContractName:String in contractsData.contracts) {
				var currentContractObj:Object = contractsData.contracts[currentContractName];
				if ((currentContractObj["deployedAt"] != undefined) && (currentContractObj["deployedAt"] != null) && (currentContractObj["deployedAt"] != "")) {
					return (true);
				}
			}
			return (false);
		}
		
		/**
		 * Adds hexadecimal data notation to a numeric string if the string doesn't have one. If the string already has "0x" notation then
		 * the input is returned as is.
		 * 
		 * @param	inputValue The hexadecimal numeric string to prepend with "0x" if this notation doesn't exist.
		 * 
		 * @return A copy of inputValue with the hexadecimal "0x" notation prepended.
		 */
		public function addHexPrefix(inputValue:String):String {
			if (inputValue.indexOf("0x") > -1) {
				return (inputValue);
			}
			inputValue = inputValue.split(" ").join("");
			return ("0x" + inputValue);
		}
	}
}