export function PoleMark({ size = 40 }: { size?: number }) {
  return (
    <span
      aria-hidden
      className="inline-block rounded-ctl border border-blue-800"
      style={{
        width: size,
        height: size,
        backgroundImage: 'repeating-linear-gradient(-45deg, #D62828 0 14px, #FFFFFF 14px 21px, #2448B8 21px 35px, #FFFFFF 35px 42px)',
        backgroundSize: '100% 100%',
      }}
    />
  );
}
