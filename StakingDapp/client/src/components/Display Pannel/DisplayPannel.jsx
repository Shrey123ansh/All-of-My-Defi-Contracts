import RewardRate from "./RewardRate";
import StakedAmount from "./StakedAmount";
import EarnedReward from "./EarnedReward";

const DisplayPannel = ()=>{
  return(   
  <div className="top-wrapper">
    <StakedAmount/>
    <RewardRate/>
    <EarnedReward/>
  </div>
  )
}
export default DisplayPannel;