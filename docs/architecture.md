# UART 송신부 설계

[프로젝트 소개](../README.md) · [검증](verification.md)

## 블록별 역할

| 블록 | 역할 | 코드 |
| --- | --- | --- |
| Response Arbiter | 입력 우선순위, 정상·에러 프레임 생성, 응답 FIFO 쓰기 | [response_arbiter.v](../rtl/response_arbiter.v) |
| Response FIFO | 4개 응답, 각 32비트 저장 | [fifo.v](../rtl/fifo.v) |
| Packetizer | 응답 pop, 필드 추출, BCD 변환 제어, ASCII·에러 문자열 출력 | [response_packetizer.v](../rtl/response_packetizer.v) |
| Double Dabble | 9비트 이진수 → 3자리 BCD | `response_packetizer.v`의 `double_dabble` 모듈 |
| UART Interface | TX/RX FIFO 연결, TX 발행 가능 상태 제공 | [uart_interface.v](../rtl/uart_interface.v) |
| UART TX | Start → Data 8bit → Stop, LSB부터 전송 | [uart_tx.v](../rtl/uart_tx.v) |
| Baud Tick | 100 MHz에서 16배 샘플링 기준 tick 생성 | [baud_tick_gen.v](../rtl/baud_tick_gen.v) |

## 입력 중재와 수락 조건

동시에 여러 입력이 유효하면 다음 순서로 하나를 선택합니다.

```text
DHT11 온습도 > SR04 거리 > Watch > Stopwatch > Error
```

응답 FIFO가 Full이면 push와 ready를 모두 내립니다. 온습도·거리·에러 입력은 대응하는 ready를 확인하는 구조입니다. Watch·Stopwatch에는 ready 출력이 없으므로, 상위 회로가 FIFO 혼잡 시 입력을 보존하거나 재시도해야 합니다. E2E 테스트는 응답 FIFO에 공간이 있을 때 입력을 넣습니다.

## 32비트 응답 프레임

정상 응답의 bit 0은 0입니다.

| 비트 | 의미 |
| --- | --- |
| `[31:30]` | 유형: Watch `00`, Stopwatch `01`, Distance `10`, 온습도 `11` |
| `[29:25]` | 시각 hour |
| `[24:19]` | 시각 minute |
| `[18:10]` | field1: 초 / 거리 / 습도 |
| `[9:1]` | field2: 온도 또는 0 |
| `[0]` | 에러 구분: 정상 0, 에러 1 |

에러 응답은 `[31:28]`에 4비트 에러 코드를 두고 `[27:1]`은 0으로 채웁니다. Packetizer가 bit 0을 먼저 검사하므로 정상 응답의 유형 필드와 별도로 해석합니다.

온습도·거리 응답의 hour/minute는 `i_watch_data`에서 가져옵니다. Stopwatch는 자체 시간 값을 사용합니다.

## ASCII 출력 형식

숫자는 최소 두 자리로 출력하고 값이 100 이상이면 세 자리로 출력합니다. 모든 패킷 끝은 LF(`0x0A`)입니다.

| 응답 | 예시 (`\n`은 LF) |
| --- | --- |
| Watch | `W H12 M34 S56\n` |
| Stopwatch | `S H01 M02 S03\n` |
| Distance | `D H12 M34 D511\n` |
| 온습도 | `H H12 M34 H55 T23\n` |
| Error 코드 1 | `ERROR: not valid operation.\n` |

에러 코드 1~8은 [Packetizer의 메시지 선택 로직](../rtl/response_packetizer.v)에서 정의합니다. 그 외 코드는 `ERROR: unknown error.` 기본 분기로 처리합니다.

## Packetizer FSM

정상 응답은 프레임 수락 후 헤더·공백·필드 문자를 출력하고, 각 숫자를 Double Dabble로 변환한 뒤 자릿수별 ASCII를 출력합니다. 마지막 필드가 끝나면 LF를 보내고 IDLE로 돌아갑니다. 에러 응답은 별도 decode/send 상태에서 메시지를 전송합니다.

ASCII를 발행하는 상태는 `i_tx_can_issue`를 확인합니다. 신호가 0이면 다음 바이트 발행을 멈추고, 다시 1이 되면 남은 바이트를 이어 보냅니다. 출력 valid는 레지스터를 거치므로 이미 발행된 1개 바이트가 뒤늦게 도착할 수 있습니다.

TX FIFO는 **32바이트**이며 Almost Full은 Full 또는 잔여 공간이 한 칸인 상태에서 활성화됩니다. `uart_interface`는 이를 반전한 `o_tx_can_issue`를 Packetizer에 전달합니다. 이 여유 공간은 현재 회로의 출력 지연을 수용하기 위한 것으로, 파이프라인 지연이 늘면 다시 검토해야 합니다.

## UART 타이밍

- 클록: 100 MHz, 주기 10 ns
- 설정: 9600 bps, 8 data bits, parity 없음, Stop 1bit
- tick 분주: `F_COUNT = 100_000_000 / (9600 × 16) = 651`
- 실제 bit 간격: `651 × 16 × 10 ns = 104.16 μs`
- TX idle은 High이며 데이터는 LSB부터 전송합니다.

`uart_rx.v`는 인터페이스를 구성하기 위해 함께 포함하지만, 이번 결과표는 RX 경로의 검증 결과를 포함하지 않습니다.
