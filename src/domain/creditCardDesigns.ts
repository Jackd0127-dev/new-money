export interface CreditCardDesign {
  id: string
  label: string
  nodeId: string
  assetPath: string
  network: 'mastercard' | 'visa'
}

export const defaultCreditCardDesignId = 'cart-minimal-11'

const cartGeometric4Colorways: CreditCardDesign[] = [
  'blue',
  'red',
  'black',
  'orange',
  'gray',
  'gold',
  'light-blue',
  'teal',
  'maroon',
  'violet',
].map((colorway) => ({
  id: `cart-geometric-4-${colorway}`,
  label: `Geometric 4 ${colorway
    .split('-')
    .map((word) => `${word.charAt(0).toUpperCase()}${word.slice(1)}`)
    .join(' ')}`,
  nodeId: '1730:4631',
  assetPath: `/figma-assets/cart-geometric-4-${colorway}`,
  network: 'mastercard' as const,
}))

export const creditCardDesigns: CreditCardDesign[] = [
  {
    id: 'cart-minimal-11',
    label: 'Minimal 11',
    nodeId: '3114:376',
    assetPath: '/figma-assets/cart-minimal-11',
    network: 'visa',
  },
  {
    id: 'cart-minimal-13',
    label: 'Minimal 13',
    nodeId: '3114:422',
    assetPath: '/figma-assets/cart-minimal-13',
    network: 'mastercard',
  },
  {
    id: 'cart-gradient-11',
    label: 'Gradient 11',
    nodeId: '3114:38',
    assetPath: '/figma-assets/cart-gradient-11',
    network: 'visa',
  },
  {
    id: 'cart-gradient-12',
    label: 'Gradient 12',
    nodeId: '3114:66',
    assetPath: '/figma-assets/cart-gradient-12',
    network: 'visa',
  },
  {
    id: 'cart-geometric-1',
    label: 'Geometric 1',
    nodeId: '1730:3774',
    assetPath: '/figma-assets/cart-geometric-1',
    network: 'visa',
  },
  {
    id: 'cart-geometric-4',
    label: 'Geometric 4',
    nodeId: '1730:4631',
    assetPath: '/figma-assets/cart-geometric-4',
    network: 'mastercard',
  },
  ...cartGeometric4Colorways,
  {
    id: 'cart-geometric-11',
    label: 'Geometric 11',
    nodeId: '3114:186',
    assetPath: '/figma-assets/cart-geometric-11',
    network: 'visa',
  },
  {
    id: 'cart-geometric-15',
    label: 'Geometric 15',
    nodeId: '3114:284',
    assetPath: '/figma-assets/cart-geometric-15',
    network: 'visa',
  },
  {
    id: 'cart-geometric-16',
    label: 'Geometric 16',
    nodeId: '3114:306',
    assetPath: '/figma-assets/cart-geometric-16',
    network: 'visa',
  },
]

const creditCardDesignIds = new Set(creditCardDesigns.map((design) => design.id))

export function normalizeCreditCardDesignId(designId?: string | null): string {
  return designId && creditCardDesignIds.has(designId) ? designId : defaultCreditCardDesignId
}

export function getCreditCardDesign(designId?: string | null): CreditCardDesign {
  const normalizedDesignId = normalizeCreditCardDesignId(designId)

  return creditCardDesigns.find((design) => design.id === normalizedDesignId) ?? creditCardDesigns[0]
}
