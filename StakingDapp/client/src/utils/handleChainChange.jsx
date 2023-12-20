export const handleChainChange=async(setState)=>{
    let chainIdHex = await window.ethereum.request(
        {method:'eth_chainId'}
    )
    const chainId = parseInt(chainIdHex,16);
    console.log(chainId)
    setState(prevState=>({...prevState,chainId}))
}