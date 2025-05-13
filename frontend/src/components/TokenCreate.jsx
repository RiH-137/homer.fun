import React, { useState } from 'react';
import '../App.css';
import { useNavigate } from 'react-router-dom';
import { abi } from './abi';
import { ethers } from 'ethers';

const TokenCreate = () => {
  const [name, setName] = useState('');
  const [ticker, setTicker] = useState('');
  const [description, setDescription] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [walletAddress, setWalletAddress] = useState('');
  const navigate = useNavigate();

  // Connect wallet function
  const connectWallet = async () => {
    if (window.ethereum) {
      try {
        const provider = new ethers.BrowserProvider(window.ethereum);
        const accounts = await provider.send("eth_requestAccounts", []);
        setWalletAddress(accounts[0]);
      } catch (error) {
        console.error("Wallet connection failed:", error);
        alert("Error connecting to wallet. Please try again.");
      }
    } else {
      alert("Please install a wallet extension like MetaMask or Trust Wallet.");
      window.open("https://trustwallet.com/browser-extension", "_blank");
    }
  };

  const handleCreate = async () => {
    try {
      if (!window.ethereum) {
        alert("Please install MetaMask!");
        return;
      }

      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();

      const contractAddress = process.env.REACT_APP_CONTRACT_ADDRESS;

      // ✅ Validate contract address:
      if (!ethers.isAddress(contractAddress)) {
        alert("Invalid contract address!");
        return;
      }

      const contract = new ethers.Contract(contractAddress, abi, signer);

      // Prepare the transaction
      const transaction = await contract.createMemeToken(
        name,
        ticker,
        imageUrl,
        description,
        {
          value: ethers.parseUnits("0.0001", "ether"),  // Meme token creation fee
          gasLimit: 500000, // Added a gas limit (adjust as necessary)
        }
      );

      const receipt = await transaction.wait();
      alert(`Transaction successful! Hash: ${receipt.hash}`);
      navigate('/');
    } catch (error) {
      console.error('Error creating token:', error);
      // Handle specific error types
      if (error.code === 'CALL_EXCEPTION') {
        alert("Transaction failed! Please check the contract parameters and try again.");
      } else {
        alert(`Error: ${error.message}`);
      }
    }
  };

  return (
    <div className="app">
      <nav className="navbar">
        <button className="nav-button" onClick={connectWallet}>
          {walletAddress ? `Wallet: ${walletAddress.slice(0, 6)}...${walletAddress.slice(-4)}` : '[connect wallet]'}
        </button>
      </nav>
      <div className="token-create-container">
        <h3 className="start-new-coin" onClick={() => navigate('/')}>[go back]</h3>
        <p className="info-text">MemeCoin creation fee: 0.0001 ETH</p>
        <p className="info-text">Max supply: 1 million tokens. Initial mint: 200k tokens.</p>
        <p className="info-text">If funding target of 24 ETH is met, a liquidity pool will be created on Uniswap.</p>
        <div className="input-container">
          <input
            type="text"
            placeholder="Token Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="input-field"
          />
          <input
            type="text"
            placeholder="Ticker Symbol"
            value={ticker}
            onChange={(e) => setTicker(e.target.value)}
            className="input-field"
          />
          <textarea
            placeholder="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="input-field"
          />
          <input
            type="text"
            placeholder="Image URL"
            value={imageUrl}
            onChange={(e) => setImageUrl(e.target.value)}
            className="input-field"
          />
          <button className="create-button" onClick={handleCreate}>
            Create MemeToken
          </button>
        </div>
      </div>
    </div>
  );
};

export default TokenCreate;
