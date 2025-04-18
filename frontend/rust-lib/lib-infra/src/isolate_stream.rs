use allo_isolate::{IntoDart, Isolate};
use anyhow::anyhow;
use futures::Sink;
pub use futures_util::sink::SinkExt;
use pin_project::pin_project;
use std::pin::Pin;
use std::task::{Context, Poll};

#[pin_project]
#[derive(Clone, Debug)]
pub struct IsolateSink {
  isolate: Isolate,
}

impl IsolateSink {
  pub fn new(isolate: Isolate) -> Self {
    Self { isolate }
  }
}

impl<T> Sink<T> for IsolateSink
where
  T: IntoDart,
{
  type Error = anyhow::Error;

  fn poll_ready(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
    Poll::Ready(Ok(()))
  }

  fn start_send(self: Pin<&mut Self>, item: T) -> Result<(), Self::Error> {
    let this = self.project();
    if this.isolate.post(item) {
      Ok(())
    } else {
      Err(anyhow!("failed to post message"))
    }
  }

  fn poll_flush(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
    Poll::Ready(Ok(()))
  }

  fn poll_close(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
    Poll::Ready(Ok(()))
  }
}
