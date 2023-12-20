import { useState,useContext,useEffect } from "react";
import {ethers} from "ethers"
import web3Context from "../../context/Web3Context"
import { toast } from "react-hot-toast";
import "./DisplayPannel.css";
const EarnedReward =()=>{
  const {stakingContract,selectedAccount}=useContext(web3Context);
  const [rewardVal,setRewardVal]=useState("0");

  useEffect(()=>{
    const fetchStakeRewardInfo =async()=>{
        try{
          //fetching earned amount of a user
           const rewardValueWei = await stakingContract.earned(selectedAccount);
           const rewardValueEth = ethers.formatUnits(rewardValueWei,18).toString();
           const roundedReward = parseFloat(rewardValueEth).toFixed(2)
           setRewardVal(roundedReward)
        }catch(error){
          toast.error("Error fetching the reward:");
          console.error(error.message)
        }
      }
        const interval = setInterval(()=>{
          stakingContract && fetchStakeRewardInfo();
        },20000)
        return ()=> clearInterval(interval)
  },[stakingContract,selectedAccount])

  return(
    <div className="earned-reward">
      <p>Earned Reward:</p>
      <span>{rewardVal}</span>
  </div>
  )
}
export default EarnedReward;