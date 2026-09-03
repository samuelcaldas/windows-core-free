import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'Windows CoreOS',
  description: 'Free, ultra-lightweight Windows Server Core distribution for Linux KVM, Proxmox, and Autonomous AI Agents.',
  base: process.env.VITEPRESS_BASE || '/windows-core-free/',

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }],
    ['meta', { name: 'theme-color', content: '#00F5D4' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'Windows CoreOS (WCOS)' }],
    ['meta', { property: 'og:description', content: 'Free Windows Server Core distribution for Linux KVM & AI Agents' }],
    ['meta', { property: 'og:image', content: '/hero.svg' }]
  ],

  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'Windows CoreOS',

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/guides/Getting-Started' },
      { text: 'Architecture', link: '/guides/Architecture-and-Hardware' },
      { text: 'Memory Tuning', link: '/guides/System-Optimization-and-Memory-Pruning' },
      { text: 'AI Agents', link: '/guides/Autonomous-AI-Agent-Workstation' },
      {
        text: 'Guides',
        items: [
          { text: 'All Documentation Guides', link: '/guides/Home' },
          { text: 'Unattended Installation', link: '/guides/Unattended-Installation' },
          { text: 'Remote Access & SSH', link: '/guides/Remote-Access-and-SSH' },
          { text: 'Desktop Shells & GUI', link: '/guides/Desktop-Shells-and-UI' },
          { text: 'OmniGet Package Manager', link: '/guides/Package-Management-with-OmniGet' },
          { text: 'Host Systemd Autostart', link: '/guides/Host-Systemd-Autostart' },
          { text: 'Proxmox & Docker Portability', link: '/guides/Proxmox-and-Docker-Portability' },
          { text: 'Brand Manual & Assets', link: '/guides/Brand-Identity-and-Assets' },
          { text: 'Agent Operating Guidelines', link: '/guides/Agent-Operating-Guidelines' },
          { text: 'Release & Versioning', link: '/guides/Release-and-Versioning-Guide' },
          { text: 'Troubleshooting & FAQ', link: '/guides/Troubleshooting-and-FAQ' }
        ]
      },
      {
        text: 'v1.0.0',
        items: [
          { text: 'GitHub Releases', link: 'https://github.com/samuelcaldas/windows-core-free/releases' },
          { text: 'Versioning Guide', link: '/guides/Release-and-Versioning-Guide' }
        ]
      }
    ],

    sidebar: [
      {
        text: '🚀 Getting Started',
        collapsed: false,
        items: [
          { text: 'Overview & Index', link: '/guides/Home' },
          { text: 'Getting Started Guide', link: '/guides/Getting-Started' },
          { text: 'Troubleshooting & FAQ', link: '/guides/Troubleshooting-and-FAQ' }
        ]
      },
      {
        text: '🏗️ Architecture & Core',
        collapsed: false,
        items: [
          { text: 'Architecture & Hardware', link: '/guides/Architecture-and-Hardware' },
          { text: 'Unattended Installation', link: '/guides/Unattended-Installation' },
          { text: 'System & Memory Optimization', link: '/guides/System-Optimization-and-Memory-Pruning' }
        ]
      },
      {
        text: '🔑 Connectivity & Infrastructure',
        collapsed: false,
        items: [
          { text: 'Remote Access & OpenSSH', link: '/guides/Remote-Access-and-SSH' },
          { text: 'Host Systemd Autostart', link: '/guides/Host-Systemd-Autostart' },
          { text: 'Proxmox & Docker Portability', link: '/guides/Proxmox-and-Docker-Portability' }
        ]
      },
      {
        text: '🖥️ Desktop, Packages & AI',
        collapsed: false,
        items: [
          { text: 'Desktop Shells & GUI', link: '/guides/Desktop-Shells-and-UI' },
          { text: 'Package Management (OmniGet)', link: '/guides/Package-Management-with-OmniGet' },
          { text: 'Autonomous AI Agent Node', link: '/guides/Autonomous-AI-Agent-Workstation' }
        ]
      },
      {
        text: '📋 Project & Governance',
        collapsed: false,
        items: [
          { text: 'Brand Identity & Assets', link: '/guides/Brand-Identity-and-Assets' },
          { text: 'Agent Operating Guidelines', link: '/guides/Agent-Operating-Guidelines' },
          { text: 'Release & Versioning Guide', link: '/guides/Release-and-Versioning-Guide' }
        ]
      }
    ],

    search: {
      provider: 'local'
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/samuelcaldas/windows-core-free' }
    ],

    footer: {
      message: 'Released under the MIT License. Windows, Hyper-V, and PowerShell are trademarks of Microsoft Corporation.',
      copyright: 'Copyright © 2026 Samuel Caldas and contributors.'
    }
  }
});
