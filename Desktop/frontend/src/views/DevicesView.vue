<script setup lang="ts">
import PageHeader from '../components/ui/PageHeader.vue';
import SegmentedTabs from '../components/ui/SegmentedTabs.vue';
import AdaptersPanel from '../components/network/AdaptersPanel.vue';
import LanDnsCard from '../components/LanDnsCard.vue';
import ClientsPanel from '../components/network/ClientsPanel.vue';
import PrivacyPanel from '../components/rules/PrivacyPanel.vue';
import EncryptedDNSPanel from '../components/encrypted/EncryptedDNSPanel.vue';
import { SUB_TABS } from '../constants/navigation';
import { useSubTab } from '../composables/useSubTab';

const props = defineProps<{ sub?: string }>();

const segments = SUB_TABS.devices ?? [];
const active = useSubTab(segments, () => props.sub, 'adapters');
</script>

<template>
  <div class="pb-12 select-none">
    <PageHeader
      title="设备"
      subtitle="接管物理网卡的 DNS 解析并开放局域网服务，为终端提供加密解析入口，识别并管控接入终端，同时防御协议隐私外泄与 DNS 重绑定攻击。"
    />
    <SegmentedTabs v-model="active" :segments="segments" />

    <AdaptersPanel v-if="active === 'adapters'" />
    <LanDnsCard v-else-if="active === 'lan'" />
    <ClientsPanel v-else-if="active === 'clients'" />
    <EncryptedDNSPanel v-else-if="active === 'encrypted'" />
    <PrivacyPanel v-else-if="active === 'privacy'" />
  </div>
</template>
