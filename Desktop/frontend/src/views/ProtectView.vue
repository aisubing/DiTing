<script setup lang="ts">
import PageHeader from '../components/ui/PageHeader.vue';
import SegmentedTabs from '../components/ui/SegmentedTabs.vue';
import RulesPanel from '../components/rules/RulesPanel.vue';
import SchedulePanel from '../components/rules/SchedulePanel.vue';
import ServicesPanel from '../components/rules/ServicesPanel.vue';
import { SUB_TABS } from '../constants/navigation';
import { useSubTab } from '../composables/useSubTab';

const props = defineProps<{ sub?: string }>();

const segments = SUB_TABS.protect ?? [];
const active = useSubTab(segments, () => props.sub, 'lists');
</script>

<template>
  <div class="pb-12 select-none">
    <PageHeader
      title="防护"
      subtitle="基于 AdGuard 语法的拦截引擎：订阅远程规则库、编写自定义规则、模拟检测拦截效果，并配置拦截应答方式与分时策略。"
    />

    <SegmentedTabs v-model="active" :segments="segments" />

    <SchedulePanel v-if="active === 'schedule'" />
    <ServicesPanel v-else-if="active === 'services'" />
    <RulesPanel v-else v-model:sub="active" />
  </div>
</template>
