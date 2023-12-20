import { useContext,useRef } from "react";
import {ethers} from "ethers"
import Web3Context from "../../context/Web3Context";
import Button from "../Button/Button";
import StakingContext from "../../context/StakingContext";
import { toast } from "react-hot-toast";
import "./StakeToken.css";

const StakeAmount =()=>{
 const {stakingContract}=useContext(Web3Context);
 const {isReload,setIsReload}=useContext(StakingContext)
 const stakeAmountRef = useRef();

 const stakeToken=async(e)=>{
   e.preventDefault();
   const amount = stakeAmountRef.current.value.trim();
   console.log(amount)
   if(isNaN(amount) || amount<=0){
    toast.error("Please enter a valid positive number.");
    return;
   }
   const amountToStake = ethers.parseUnits(amount,18).toString();
   try{
    const transaction = await stakingContract.stake(amountToStake)
    await toast.promise(transaction.wait(),
    {
      loading: "Transaction is pending...",
      success: 'Transaction successful 👌',
      error: 'Transaction failed 🤯'
    });
    stakeAmountRef.current.value = "";
    setIsReload(!isReload);
    // if (receipt.status === 1) {
    //     setIsReload(!isReload);
    //     stakeAmountRef.current.value = "";
    //   } else {
    //       toast.error("Transaction failed. Please try again.")
    //   }
    } catch (error) {
      toast.error("Staking Failed");
      console.error(error.message)
    }
  };
    return (
      <form onSubmit={stakeToken} className="stake-amount-form">
        <label className="stake-input-label">Enter Staked Amount:</label>
        <input type="text" ref={stakeAmountRef} />
        <Button onClick={stakeToken} type="submit" label="Stake Token" />
      </form>
       )
}
export default StakeAmount;