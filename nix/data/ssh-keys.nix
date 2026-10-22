# Public SSH keys, keyed by human-readable label.
# Drop pubkeys here and reference them by name from authorizedKeys lists.
{
  kp2pml30-personal-pc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2dRBDECmIuKt+2B2q9cmFudKga+EzbD4pCX6x3JNLB kp2pml30@kp2pml30-personal-pc";
  kp2pml30-ideapad = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBa/qqEPRkzR1QY3ugWvUhGSykgrCLpd+fXJzwCXJN/ kp2pml30@kp2pml30-personal-laptop";

  # host key of the nanopi initrd sshd, private half on its /boot
  nanopi-m5-initrd = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIF17ijDjIQ6sFMISEJylqbfnhmz7JeQUHwzHa9kVivw nanopi-m5-initrd";
}
