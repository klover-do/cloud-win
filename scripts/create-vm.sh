
#!/usr/bin/env bash
set -euo pipefail

ROOT="/opt/cloudwin"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo $0"
  exit 1
fi

if [[ ! -f "$ROOT/config.env" ]]; then
  echo "Missing config.env"
  exit 1
fi

set -a
source "$ROOT/config.env"
set +a

: "${VM_NAME:=cloudwin}"
: "${VM_RAM_MIB:=8192}"
: "${VM_VCPUS:=4}"
: "${VM_DISK_GIB:=80}"
: "${VM_DISK_PATH:=/var/lib/libvirt/images/cloudwin.qcow2}"
: "${WINDOWS_ISO:=/var/lib/cloudwin/iso/windows.iso}"
: "${VIRTIO_ISO:=/var/lib/cloudwin/iso/virtio-win.iso}"
: "${VNC_PORT:=5900}"

if [[ ! -f "$WINDOWS_ISO" ]]; then
  echo "Windows ISO not found: $WINDOWS_ISO"
  exit 1
fi

if virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
  echo "VM already exists. Refusing to overwrite."
  exit 1
fi

if [[ -e "$VM_DISK_PATH" ]]; then
  echo "Disk already exists. Refusing to overwrite."
  exit 1
fi

install -d "$(dirname "$VM_DISK_PATH")"

qemu-img create -f qcow2 \
  "$VM_DISK_PATH" "${VM_DISK_GIB}G"

chown libvirt-qemu:kvm "$VM_DISK_PATH" 2>/dev/null || true
chmod 660 "$VM_DISK_PATH"

VIRTIO_XML=""

if [[ -f "$VIRTIO_ISO" ]]; then
  VIRTIO_XML="<disk type='file' device='cdrom'>
    <driver name='qemu' type='raw'/>
    <source file='$VIRTIO_ISO'/>
    <target dev='sdb' bus='sata'/>
    <readonly/>
  </disk>"
fi

cat > /tmp/cloudwin.xml <<EOF
<domain type='kvm'>
  <name>${VM_NAME}</name>
  <memory unit='MiB'>${VM_RAM_MIB}</memory>
  <currentMemory unit='MiB'>${VM_RAM_MIB}</currentMemory>
  <vcpu placement='static'>${VM_VCPUS}</vcpu>

  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <boot dev='cdrom'/>
    <boot dev='hd'/>
  </os>

  <features>
    <acpi/>
    <apic/>
  </features>

  <cpu mode='host-passthrough' check='none'/>

  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>

    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='${VM_DISK_PATH}'/>
      <target dev='vda' bus='virtio'/>
    </disk>

    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='${WINDOWS_ISO}'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>

    ${VIRTIO_XML}

    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>

    <graphics type='vnc'
      port='${VNC_PORT}'
      autoport='no'
      listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>

    <video>
      <model type='virtio' heads='1'/>
    </video>

    <input type='tablet' bus='usb'/>
  </devices>
</domain>
EOF

virsh define /tmp/cloudwin.xml
rm -f /tmp/cloudwin.xml

echo "CloudWin VM created!"
