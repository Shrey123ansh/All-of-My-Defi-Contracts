import { useState } from "react"
import Wallet from "./components/Wallet/Wallet"
import Navigation from "./components/Navigation/Navigation"
import DisplayPannel from './components/Display Pannel/DisplayPannel'
import TokenApproval from './components/StakeToken/TokenApproval'
import StakeAmount from './components/StakeToken/StakeAmount'
import WithdrawStakeAmount from './components/Withdraw/Withdraw'
import { StakingProvider } from './context/StakingContext'
import './App.css'
function App() {

  const [displaySection, setDisplaySection] = useState("stake");

  const handleButtonClick = (section) => {
    setDisplaySection(section);
  };

  return (
    <div className="main-section">
      <Wallet>
        <Navigation />
        <StakingProvider>
          <DisplayPannel />
          <div className="main-content">
            <div className="button-section">
              <button
                onClick={() => handleButtonClick("stake")}
                className={displaySection === "stake" ? "" : "active"}
              >
                Stake
              </button>
              <button
                onClick={() => handleButtonClick("withdraw")}
                className={displaySection === "withdraw" ? "" : "active"}
              >
                Withdraw
              </button>
            </div>
            {displaySection === "stake" && (
              <div className="stake-wrapper">
                <TokenApproval />
                <StakeAmount />
              </div>
            )}
            {displaySection === "withdraw" && (
              <div className="stake-wrapper">
                <WithdrawStakeAmount />
              </div>
            )}
          </div>
        </StakingProvider>
      </Wallet>
    </div>
  )
}

export default App
