// 商家归属（v1.17.10）：按节点 id 查商家名 + 官网。
// 只有核实过的才进表——id 与商家对应关系来自用户实测/后台截图，
// 官网域名来自已验证的记录（AkkoCloud akkocloud.com 首页为 WHMCS 门户，
// 2026-11-07 实测；六六云 666clouds.com/market 为用户指定的二手市场地址）。
// Zouter 官网域名未核实，只记商家名、不给链接，不猜域名。
// 未登记的节点：商家未知，不显示商家行、不参与同商家分组，不编。

/// 商家信息：name 为商家名，site 为官网（null = 未核实，不显示链接）。
class MerchantInfo {
  final String name;
  final String? site;
  const MerchantInfo(this.name, [this.site]);
}

/// 节点 id → 商家。只含已核实的四台节点。
const Map<String, MerchantInfo> merchantByNodeId = {
  // 圣何塞 CN2 GIA：AkkoCloud，2026-10-23 下单
  'Vps-mvjxvzf1': MerchantInfo('AkkoCloud', 'https://akkocloud.com/'),
  // 美西 4837：六六云，2026-10-18 下单
  'us-4837': MerchantInfo('六六云', 'https://666clouds.com/'),
  // 英国 9929：六六云
  'uk-vps': MerchantInfo('六六云', 'https://666clouds.com/'),
  // 香港 hk-v6：Zouter，官网域名未核实
  'hk-vps': MerchantInfo('Zouter'),
};

MerchantInfo? merchantOf(String nodeId) => merchantByNodeId[nodeId];
