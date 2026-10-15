<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { ProviderConfig } from '../../api/types';
import { ipc } from '../../api/ipc';
import { DNS_PRESET_PROVIDERS, type DnsProtocolType } from '../../constants/dnsPresets';
import { validateDoHUrl } from '../../utils/validators';
import AppModal from '../AppModal.vue';
import InlineAlert from '../ui/InlineAlert.vue';
import M3Icon from '../M3Icon.vue';

const props = defineProps<{
  open: boolean;
  editingItem: ProviderConfig | null;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'save', item: ProviderConfig): void;
}>();

const formId = ref('');
const formProtocol = ref<DnsProtocolType>('DOT');
const formServer = ref('');
const formUrl = ref('');
const formWeight = ref(1);
// 证书固定指纹：非空即接管证书校验，故需在界面上显著提示
const formPin = ref('');

const currentPresetProvider = ref('阿里云');
const currentPresetProtocol = ref<DnsProtocolType>('DOT');
const selectedPresetDesc = ref('阿里巴巴公共 DNS，基于 TLS 的加密解析');
const formError = ref('');

// 印章粘贴与解析状态
const stampInput = ref('');
const stampParsing = ref(false);
const stampError = ref('');
const stampSummary = ref('');

const protocolOptions = [
  { label: '普通 DNS', value: 'PLAIN' as DnsProtocolType },
  { label: '加密 DoT', value: 'DOT' as DnsProtocolType },
  { label: '加密 DoH', value: 'DOH' as DnsProtocolType },
  { label: '加密 DoH3', value: 'DOH3' as DnsProtocolType },
  { label: '加密 DoQ', value: 'DOQ' as DnsProtocolType },
];

// 遍历预设时使用的协议顺序，与 protocolOptions 保持一致
const PROTOCOL_ORDER: DnsProtocolType[] = ['PLAIN', 'DOT', 'DOH', 'DOH3', 'DOQ'];

// DoH 与 DoH3 同属 HTTPS 语义：均需填写 URL，且共用同一套地址校验
const isHttpsStyleProtocol = computed(
  () => formProtocol.value === 'DOH' || formProtocol.value === 'DOH3'
);

function applyPreset(providerName: string, protocol: DnsProtocolType) {
  currentPresetProvider.value = providerName;
  currentPresetProtocol.value = protocol;

  const group = DNS_PRESET_PROVIDERS.find((p) => p.name === providerName);
  const preset = group?.presets[protocol];
  if (!preset) {
    // 该服务商未提供此协议的公开端点：只切换协议选择，不臆造地址覆盖用户已填内容
    formProtocol.value = protocol;
    selectedPresetDesc.value = `${providerName} 暂未提供该协议的公开端点，请手动填写`;
    return;
  }

  formId.value = preset.id;
  formProtocol.value = preset.protocol;
  formServer.value = preset.server;
  formUrl.value = preset.url || '';
  formPin.value = '';
  selectedPresetDesc.value = preset.description || '';
}

function handleProtocolSelect(proto: DnsProtocolType) {
  formProtocol.value = proto;
  currentPresetProtocol.value = proto;
  if (currentPresetProvider.value) {
    const group = DNS_PRESET_PROVIDERS.find((p) => p.name === currentPresetProvider.value);
    if (group && group.presets[proto]) {
      selectedPresetDesc.value = group.presets[proto].description || '';
    }
  }
}

watch(
  () => props.open,
  (open) => {
    if (open) {
      formError.value = '';
      if (props.editingItem) {
        const item = props.editingItem;
        formId.value = item.id;
        formProtocol.value = item.protocol;
        formServer.value = item.server;
        formUrl.value = item.url || '';
        formWeight.value = item.weight ?? 1;
        formPin.value = item.pin || '';

        let matched = false;
        for (const group of DNS_PRESET_PROVIDERS) {
          for (const proto of PROTOCOL_ORDER) {
            const p = group.presets[proto];
            if (!p) continue;
            if (p.id === item.id || (p.server === item.server && p.protocol === item.protocol)) {
              currentPresetProvider.value = group.name;
              currentPresetProtocol.value = p.protocol;
              selectedPresetDesc.value = p.description || '';
              matched = true;
              break;
            }
          }
          if (matched) break;
        }
        if (!matched) {
          currentPresetProvider.value = '';
          currentPresetProtocol.value = item.protocol;
          selectedPresetDesc.value = '';
        }
      } else {
        applyPreset('阿里云', 'DOT');
        formWeight.value = 1;
        formPin.value = '';
      }
      stampInput.value = '';
      stampError.value = '';
      stampSummary.value = '';
    }
  }
);

// 解析 sdns:// 印章并回填表单。印章自带主机名、路径与证书指纹，
// 手工填写这些字段极易出错，故提供一次粘贴即可完成的入口。
async function handleParseStamp() {
  stampError.value = '';
  stampSummary.value = '';
  const raw = stampInput.value.trim();
  if (!raw) {
    stampError.value = '请先粘贴 sdns:// 印章';
    return;
  }

  stampParsing.value = true;
  try {
    const res = await ipc.parseStamp(raw);
    formProtocol.value = res.protocol as DnsProtocolType;
    currentPresetProtocol.value = res.protocol as DnsProtocolType;
    formServer.value = res.server;
    formUrl.value = res.url || '';
    formPin.value = res.pin || '';
    if (!formId.value.trim()) {
      formId.value = res.providerName || res.server;
    }
    // 该服务商预设中可能没有此协议，避免残留描述误导用户
    currentPresetProvider.value = '';
    selectedPresetDesc.value = '';

    const parts = [`已解析为 ${res.protoName}`];
    if (res.providerName) parts.push(`主机 ${res.providerName}`);
    if (res.pin) parts.push('已载入证书指纹');
    if (res.props.dnssec) parts.push('声明支持 DNSSEC');
    if (res.props.noLog) parts.push('声明不记录日志');
    stampSummary.value = parts.join(' · ');
  } catch (err) {
    stampError.value = err instanceof Error ? err.message : '印章解析失败';
  } finally {
    stampParsing.value = false;
  }
}

function clearStamp() {
  stampInput.value = '';
  stampError.value = '';
  stampSummary.value = '';
}

function handleSave() {
  formError.value = '';
  if (!formId.value.trim() || !formServer.value.trim()) {
    formError.value = '服务器名称与地址不得为空';
    return;
  }

  if (isHttpsStyleProtocol.value) {
    const check = validateDoHUrl(formUrl.value);
    if (!check.valid) {
      formError.value = check.error || 'DoH 地址格式无效';
      return;
    }
  }

  const item: ProviderConfig = {
    id: formId.value.trim(),
    protocol: formProtocol.value,
    server: formServer.value.trim(),
    url: formUrl.value.trim(),
    weight: formWeight.value,
  };
  const pin = formPin.value.trim();
  if (pin) {
    item.pin = pin;
  }

  emit('save', item);
}
</script>

<template>
  <AppModal
    :open="open"
    @close="emit('close')"
    :title="editingItem ? '编辑 DNS 服务器' : '添加 DNS 服务器'"
  >
    <form id="upstream-dialog-form" @submit.prevent="handleSave" class="space-y-4 pt-1">
      <!-- 常用推荐预设快速填入 -->
      <div class="rounded-md border border-surface-border bg-surface-card-sub p-3 space-y-2.5">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold text-text-sub flex items-center gap-1.5">
            <M3Icon name="bolt" :size="14" class="text-text-main" />
            常用推荐预设 (点击快速填入):
          </span>
          <span v-if="selectedPresetDesc" class="text-[11px] text-text-sub truncate max-w-[210px]" :title="selectedPresetDesc">
            {{ selectedPresetDesc }}
          </span>
        </div>

        <!-- 服务商 Chips -->
        <div class="space-y-1">
          <div class="text-[11px] text-text-sub">服务商:</div>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="provider in DNS_PRESET_PROVIDERS"
              :key="provider.name"
              type="button"
              @click="applyPreset(provider.name, currentPresetProtocol)"
              class="app-btn-chip"
              :class="{ active: currentPresetProvider === provider.name }"
            >
              {{ provider.name }}
            </button>
          </div>
        </div>

        <!-- 协议 Chips -->
        <div class="space-y-1">
          <div class="text-[11px] text-text-sub">解析协议:</div>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="proto in protocolOptions"
              :key="proto.value"
              type="button"
              @click="applyPreset(currentPresetProvider || '阿里云', proto.value)"
              class="app-btn-chip"
              :class="{ active: currentPresetProtocol === proto.value }"
            >
              {{ proto.label }}
            </button>
          </div>
        </div>
      </div>

      <!-- 印章粘贴：一次填入协议、地址、路径与证书指纹 -->
      <div class="rounded-md border border-surface-border bg-surface-card-sub p-3 space-y-2.5">
        <div class="text-xs font-semibold text-text-sub flex items-center gap-1.5">
          <M3Icon name="shield" :size="14" class="text-text-main" />
          DNS 印章 (sdns://) 快速解析:
        </div>
        <div class="flex gap-2">
          <md-outlined-text-field
            label="粘贴印章"
            :value="stampInput"
            @input="stampInput = ($event.target as any).value"
            class="w-full font-mono"
            placeholder="sdns://..."
          ></md-outlined-text-field>
          <button
            type="button"
            class="app-btn-secondary shrink-0"
            :disabled="stampParsing"
            @click="handleParseStamp"
          >
            {{ stampParsing ? '解析中…' : '解析' }}
          </button>
        </div>
        <InlineAlert v-if="stampError" :message="stampError" type="error" />
        <div v-if="stampSummary" class="flex items-start justify-between gap-2">
          <span class="text-[11px] text-status-success">{{ stampSummary }}</span>
          <button type="button" class="text-[11px] text-text-sub underline shrink-0" @click="clearStamp">
            清除
          </button>
        </div>
      </div>

      <InlineAlert v-if="formError" :message="formError" type="error" />

      <md-outlined-text-field
        label="服务器名称 / 标识"
        :value="formId"
        @input="formId = ($event.target as any).value"
        class="w-full"
        required
      ></md-outlined-text-field>

      <md-outlined-select
        label="连接协议"
        :value="formProtocol"
        @change="handleProtocolSelect(($event.target as any).value)"
        class="w-full"
      >
        <md-select-option value="PLAIN">
          <div slot="headline">普通模式 (标准 DNS / 端口 53)</div>
        </md-select-option>
        <md-select-option value="DOH">
          <div slot="headline">加密模式 (DNS over HTTPS / 安全防窥探)</div>
        </md-select-option>
        <md-select-option value="DOH3">
          <div slot="headline">加密模式 (DNS over HTTP/3 / QUIC 承载，抗丢包)</div>
        </md-select-option>
        <md-select-option value="DOT">
          <div slot="headline">加密模式 (DNS over TLS / 端口 853)</div>
        </md-select-option>
        <md-select-option value="DOQ">
          <div slot="headline">加密模式 (DNS over QUIC / 端口 853，握手更快)</div>
        </md-select-option>
      </md-outlined-select>

      <md-outlined-text-field
        label="服务器地址 (IP 或域名)"
        :value="formServer"
        @input="formServer = ($event.target as any).value"
        class="w-full font-mono"
        placeholder="如 223.5.5.5:53 或 dns.alidns.com"
      ></md-outlined-text-field>

      <md-outlined-text-field
        v-if="isHttpsStyleProtocol"
        label="加密解析地址 (URL)"
        :value="formUrl"
        @input="formUrl = ($event.target as any).value"
        class="w-full font-mono"
        placeholder="https://dns.alidns.com/dns-query"
      ></md-outlined-text-field>

      <div class="space-y-1.5">
        <md-outlined-text-field
          label="证书指纹 (可选，SHA-256)"
          :value="formPin"
          @input="formPin = ($event.target as any).value"
          class="w-full font-mono"
          placeholder="AA:BB:CC:…（留空即沿用系统 CA 校验）"
        ></md-outlined-text-field>
        <p v-if="formPin.trim()" class="text-[11px] text-status-warning leading-relaxed">
          ⚠ 填写指纹后将<strong>替代</strong>系统 CA 链校验，仅适用于自签或私有 CA
          部署的上游。指纹不匹配时该上游将完全不可用。
        </p>
      </div>
    </form>

    <template #actions>
      <button
        type="button"
        @click="emit('close')"
        class="app-btn-secondary"
      >
        取消
      </button>
      <button
        type="button"
        @click="handleSave"
        class="app-btn-primary"
      >
        保存服务器
      </button>
    </template>
  </AppModal>
</template>
