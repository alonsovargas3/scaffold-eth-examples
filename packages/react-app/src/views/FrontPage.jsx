import React, { useCallback, useEffect, useState } from "react";
import { Button, List, Modal, Input, Card, DatePicker, Slider, Switch, Progress, Spin } from "antd";
import { SyncOutlined } from "@ant-design/icons";
import { parseEther, formatEther } from "@ethersproject/units";
import { ethers } from "ethers";
import QR from "qrcode.react";
import { useContractReader, useEventListener, useLocalStorage, useLookupAddress } from "../hooks";
import { Address, AddressInput, Balance, Blockie, TransactionListItem } from "../components";

const axios = require("axios");

export default function FrontPage({
  executeTransactionEvents,
  contractName,
  localProvider,
  readContracts,
  price,
  owner,
  mainnetProvider,
  blockExplorer,
}) {
  const [methodName, setMethodName] = useLocalStorage("addSigner");
  return (
    <div style={{ padding: 32, maxWidth: 750, margin: "auto" }}>
      <div style={{ paddingBottom: 32 }}>
        <div>
          <Balance
            address={readContracts ? readContracts[contractName].address : readContracts}
            provider={localProvider}
            dollarMultiplier={price}
            fontSize={64}
          />
        </div>
        <div>
          <QR
            value={readContracts ? readContracts[contractName].address : ""}
            size="180"
            level="H"
            includeMargin
            renderAs="svg"
            imageSettings={{ excavate: false }}
          />
        </div>
        <div>
          <Address
            address={readContracts ? readContracts[contractName].address : readContracts}
            ensProvider={mainnetProvider}
            blockExplorer={blockExplorer}
            fontSize={32}
          />
        </div>
      </div>
      <h2 style={{marginTop:32}}>Executed Transactions</h2>
      <List
        bordered
        dataSource={executeTransactionEvents}
        renderItem={item => {

          return (
            <List.Item key={"owner_"+item["owner"]}>
            <div style={{padding:16}}>
              {item["txIndex"]?Number(item["txIndex"]):""}
            </div>
            <Address
              address={item["owner"]}
              ensProvider={mainnetProvider}
              blockExplorer={blockExplorer}
              fontSize={32}
            />
            <Address
              address={item["to"]}
              ensProvider={mainnetProvider}
              blockExplorer={blockExplorer}
              fontSize={32}
            />
            <div style={{padding:16}}>
              {item["value"]?(Number(item["value"]/1000000000000000000)):""}
            </div>
            <div style={{padding:16}}>
              {item["data"].toString()}
            </div>
            </List.Item>
          )
        }}
      />
    </div>
  );
}
