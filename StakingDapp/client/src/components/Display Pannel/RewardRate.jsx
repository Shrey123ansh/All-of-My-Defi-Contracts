import { useState,useEffect,useContext } from "react";
import Web3Context from "../../context/Web3Context";
import {ethers} from "ethers"
import { toast } from "react-hot-toast";
import "./DisplayPannel.css";
const RewardRate = ()=>{
  const {stakingContract,selectedAccount}=useContext(Web3Context);
  const [rewardRate,setRewardRate]=useState("0");

  useEffect(()=>{
    const fetchRewardRate = async()=>{
       try{
          const rewardRateWei = await stakingContract.REWARD_RATE();
          const rewardRateEth = ethers.formatUnits(rewardRateWei.toString(),18);
          setRewardRate(rewardRateEth)
        }catch(error){
          toast.error("Error fetching reward rate");
          console.error(error.message)
       }
    }
    stakingContract && fetchRewardRate()
  },[stakingContract,selectedAccount])

  return(
    <div className="reward-rate">
      <p>Reward Rate:</p>
      <span>{rewardRate} token/sec </span>
  </div>
  )
}
export default RewardRate;